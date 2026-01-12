library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tft_st7735 is
    generic (
        WIDTH   : integer := 128;
        HEIGHT  : integer := 160;
        SPI_DIV : integer := 4  -- SCK = 50MHz / (2*SPI_DIV)
    );
    port (
        clk : in std_logic;
        rst : in std_logic;

        -- Framebuffer control/data
        use_fb  : in  std_logic;
        fb_addr : out unsigned(14 downto 0);
        fb_data : in  std_logic_vector(15 downto 0);
        osd_status : in std_logic_vector(15 downto 0);

        -- TFT pins (SPI, mode 0)
        tft_cs_n    : out std_logic;
        tft_reset_n : out std_logic;
        tft_dc      : out std_logic;
        tft_sck     : out std_logic;
        tft_mosi    : out std_logic
    );
end entity;

architecture rtl of tft_st7735 is
    constant CLK_HZ        : integer := 50_000_000;
    constant CYCLES_PER_MS : integer := CLK_HZ / 1000;

    constant PIXELS : integer := WIDTH * HEIGHT;
    constant OSD_HEIGHT : integer := 16;

    type int5_t is array (0 to 4) of integer;

    type state_type is (
        S_RESET_LOW,
        S_RESET_WAIT,
        S_WAIT_SPI,
        S_INIT_SWRESET,
        S_DELAY_150MS,
        S_INIT_SLPOUT,
        S_INIT_COLMOD_CMD,
        S_INIT_COLMOD_DATA,
        S_DELAY_10MS,
        S_INIT_MADCTL_CMD,
        S_INIT_MADCTL_DATA,
        S_INIT_CASET_CMD, S_INIT_CASET_0, S_INIT_CASET_1, S_INIT_CASET_2, S_INIT_CASET_3,
        S_INIT_RASET_CMD, S_INIT_RASET_0, S_INIT_RASET_1, S_INIT_RASET_2, S_INIT_RASET_3,
        S_INIT_NORON,
        S_INIT_DISPON,
        S_DELAY_100MS,
        S_FRAME_RAMWR,
        S_PIXEL_SET_ADDR,
        S_PIXEL_WAIT,
        S_PIXEL_LATCH,
        S_PIXEL_SEND_MSB,
        S_PIXEL_SEND_LSB
    );

    signal state : state_type := S_RESET_LOW;
    signal after_spi_state : state_type := S_RESET_LOW;

    -- Delay timer
    signal delay_cnt : unsigned(31 downto 0) := (others => '0');

    -- Framebuffer addressing
    signal fb_addr_r : unsigned(14 downto 0) := (others => '0');
    signal pixel_idx : integer range 0 to PIXELS - 1 := 0;
    signal pixel_reg : std_logic_vector(15 downto 0) := (others => '0');
    signal use_fb_latched : std_logic := '0';
    signal osd_status_latched : std_logic_vector(15 downto 0) := (others => '0');

    -- SPI byte engine
    signal spi_start : std_logic := '0';
    signal spi_byte  : std_logic_vector(7 downto 0) := (others => '0');

    signal spi_busy    : std_logic := '0';
    signal spi_done    : std_logic := '0';
    signal spi_sck_r   : std_logic := '0';
    signal spi_mosi_r  : std_logic := '0';
    signal spi_div_cnt : integer range 0 to SPI_DIV - 1 := 0;
    signal spi_bit_idx : integer range 0 to 7 := 7;
    signal spi_shift   : std_logic_vector(7 downto 0) := (others => '0');

    signal cs_n_r    : std_logic := '1';
    signal dc_r      : std_logic := '0';
    signal reset_n_r : std_logic := '0';

    function hex_nibble_to_ascii(n : unsigned(3 downto 0)) return std_logic_vector is
        variable v : integer;
        variable a : unsigned(7 downto 0);
    begin
        v := to_integer(n);
        if v < 10 then
            a := to_unsigned(16#30# + v, 8); -- '0'..'9'
        else
            a := to_unsigned(16#41# + (v - 10), 8); -- 'A'..'F'
        end if;
        return std_logic_vector(a);
    end function;

    function glyph_row_5x7(c : std_logic_vector(7 downto 0); row : integer) return std_logic_vector is
        variable r : std_logic_vector(4 downto 0) := (others => '0');
        variable ch : integer := to_integer(unsigned(c));
    begin
        if row < 0 or row > 6 then
            return r;
        end if;

        case ch is
            when 32 => -- ' '
                r := "00000";
            when 45 => -- '-'
                case row is
                    when 3 => r := "11111";
                    when others => r := "00000";
                end case;

            -- Digits 0-9
            when 48 => -- '0'
                case row is
                    when 0 => r := "01110";
                    when 1 => r := "10001";
                    when 2 => r := "10011";
                    when 3 => r := "10101";
                    when 4 => r := "11001";
                    when 5 => r := "10001";
                    when others => r := "01110";
                end case;
            when 49 => -- '1'
                case row is
                    when 0 => r := "00100";
                    when 1 => r := "01100";
                    when 2 => r := "00100";
                    when 3 => r := "00100";
                    when 4 => r := "00100";
                    when 5 => r := "00100";
                    when others => r := "01110";
                end case;
            when 50 => -- '2'
                case row is
                    when 0 => r := "01110";
                    when 1 => r := "10001";
                    when 2 => r := "00001";
                    when 3 => r := "00010";
                    when 4 => r := "00100";
                    when 5 => r := "01000";
                    when others => r := "11111";
                end case;
            when 51 => -- '3'
                case row is
                    when 0 => r := "11110";
                    when 1 => r := "00001";
                    when 2 => r := "00001";
                    when 3 => r := "01110";
                    when 4 => r := "00001";
                    when 5 => r := "00001";
                    when others => r := "11110";
                end case;
            when 52 => -- '4'
                case row is
                    when 0 => r := "00010";
                    when 1 => r := "00110";
                    when 2 => r := "01010";
                    when 3 => r := "10010";
                    when 4 => r := "11111";
                    when 5 => r := "00010";
                    when others => r := "00010";
                end case;
            when 53 => -- '5'
                case row is
                    when 0 => r := "11111";
                    when 1 => r := "10000";
                    when 2 => r := "10000";
                    when 3 => r := "11110";
                    when 4 => r := "00001";
                    when 5 => r := "00001";
                    when others => r := "11110";
                end case;
            when 54 => -- '6'
                case row is
                    when 0 => r := "01110";
                    when 1 => r := "10000";
                    when 2 => r := "10000";
                    when 3 => r := "11110";
                    when 4 => r := "10001";
                    when 5 => r := "10001";
                    when others => r := "01110";
                end case;
            when 55 => -- '7'
                case row is
                    when 0 => r := "11111";
                    when 1 => r := "00001";
                    when 2 => r := "00010";
                    when 3 => r := "00100";
                    when 4 => r := "01000";
                    when 5 => r := "01000";
                    when others => r := "01000";
                end case;
            when 56 => -- '8'
                case row is
                    when 0 => r := "01110";
                    when 1 => r := "10001";
                    when 2 => r := "10001";
                    when 3 => r := "01110";
                    when 4 => r := "10001";
                    when 5 => r := "10001";
                    when others => r := "01110";
                end case;
            when 57 => -- '9'
                case row is
                    when 0 => r := "01110";
                    when 1 => r := "10001";
                    when 2 => r := "10001";
                    when 3 => r := "01111";
                    when 4 => r := "00001";
                    when 5 => r := "00001";
                    when others => r := "01110";
                end case;

            -- Letters A-Z (subset used by OSD, but implementing full set keeps it simple)
            when 65 => -- 'A'
                case row is
                    when 0 => r := "01110";
                    when 1 => r := "10001";
                    when 2 => r := "10001";
                    when 3 => r := "11111";
                    when 4 => r := "10001";
                    when 5 => r := "10001";
                    when others => r := "10001";
                end case;
            when 66 => -- 'B'
                case row is
                    when 0 => r := "11110";
                    when 1 => r := "10001";
                    when 2 => r := "10001";
                    when 3 => r := "11110";
                    when 4 => r := "10001";
                    when 5 => r := "10001";
                    when others => r := "11110";
                end case;
            when 67 => -- 'C'
                case row is
                    when 0 => r := "01110";
                    when 1 => r := "10001";
                    when 2 => r := "10000";
                    when 3 => r := "10000";
                    when 4 => r := "10000";
                    when 5 => r := "10001";
                    when others => r := "01110";
                end case;
            when 68 => -- 'D'
                case row is
                    when 0 => r := "11100";
                    when 1 => r := "10010";
                    when 2 => r := "10001";
                    when 3 => r := "10001";
                    when 4 => r := "10001";
                    when 5 => r := "10010";
                    when others => r := "11100";
                end case;
            when 69 => -- 'E'
                case row is
                    when 0 => r := "11111";
                    when 1 => r := "10000";
                    when 2 => r := "10000";
                    when 3 => r := "11110";
                    when 4 => r := "10000";
                    when 5 => r := "10000";
                    when others => r := "11111";
                end case;
            when 70 => -- 'F'
                case row is
                    when 0 => r := "11111";
                    when 1 => r := "10000";
                    when 2 => r := "10000";
                    when 3 => r := "11110";
                    when 4 => r := "10000";
                    when 5 => r := "10000";
                    when others => r := "10000";
                end case;
            when 71 => -- 'G'
                case row is
                    when 0 => r := "01110";
                    when 1 => r := "10001";
                    when 2 => r := "10000";
                    when 3 => r := "10111";
                    when 4 => r := "10001";
                    when 5 => r := "10001";
                    when others => r := "01110";
                end case;
            when 72 => -- 'H'
                case row is
                    when 0 => r := "10001";
                    when 1 => r := "10001";
                    when 2 => r := "10001";
                    when 3 => r := "11111";
                    when 4 => r := "10001";
                    when 5 => r := "10001";
                    when others => r := "10001";
                end case;
            when 73 => -- 'I'
                case row is
                    when 0 => r := "01110";
                    when 1 => r := "00100";
                    when 2 => r := "00100";
                    when 3 => r := "00100";
                    when 4 => r := "00100";
                    when 5 => r := "00100";
                    when others => r := "01110";
                end case;
            when 74 => -- 'J'
                case row is
                    when 0 => r := "00001";
                    when 1 => r := "00001";
                    when 2 => r := "00001";
                    when 3 => r := "00001";
                    when 4 => r := "10001";
                    when 5 => r := "10001";
                    when others => r := "01110";
                end case;
            when 75 => -- 'K'
                case row is
                    when 0 => r := "10001";
                    when 1 => r := "10010";
                    when 2 => r := "10100";
                    when 3 => r := "11000";
                    when 4 => r := "10100";
                    when 5 => r := "10010";
                    when others => r := "10001";
                end case;
            when 76 => -- 'L'
                case row is
                    when 0 => r := "10000";
                    when 1 => r := "10000";
                    when 2 => r := "10000";
                    when 3 => r := "10000";
                    when 4 => r := "10000";
                    when 5 => r := "10000";
                    when others => r := "11111";
                end case;
            when 77 => -- 'M'
                case row is
                    when 0 => r := "10001";
                    when 1 => r := "11011";
                    when 2 => r := "10101";
                    when 3 => r := "10101";
                    when 4 => r := "10001";
                    when 5 => r := "10001";
                    when others => r := "10001";
                end case;
            when 78 => -- 'N'
                case row is
                    when 0 => r := "10001";
                    when 1 => r := "10001";
                    when 2 => r := "11001";
                    when 3 => r := "10101";
                    when 4 => r := "10011";
                    when 5 => r := "10001";
                    when others => r := "10001";
                end case;
            when 79 => -- 'O'
                case row is
                    when 0 => r := "01110";
                    when 1 => r := "10001";
                    when 2 => r := "10001";
                    when 3 => r := "10001";
                    when 4 => r := "10001";
                    when 5 => r := "10001";
                    when others => r := "01110";
                end case;
            when 80 => -- 'P'
                case row is
                    when 0 => r := "11110";
                    when 1 => r := "10001";
                    when 2 => r := "10001";
                    when 3 => r := "11110";
                    when 4 => r := "10000";
                    when 5 => r := "10000";
                    when others => r := "10000";
                end case;
            when 81 => -- 'Q'
                case row is
                    when 0 => r := "01110";
                    when 1 => r := "10001";
                    when 2 => r := "10001";
                    when 3 => r := "10001";
                    when 4 => r := "10101";
                    when 5 => r := "10010";
                    when others => r := "01101";
                end case;
            when 82 => -- 'R'
                case row is
                    when 0 => r := "11110";
                    when 1 => r := "10001";
                    when 2 => r := "10001";
                    when 3 => r := "11110";
                    when 4 => r := "10100";
                    when 5 => r := "10010";
                    when others => r := "10001";
                end case;
            when 83 => -- 'S'
                case row is
                    when 0 => r := "01111";
                    when 1 => r := "10000";
                    when 2 => r := "10000";
                    when 3 => r := "01110";
                    when 4 => r := "00001";
                    when 5 => r := "00001";
                    when others => r := "11110";
                end case;
            when 84 => -- 'T'
                case row is
                    when 0 => r := "11111";
                    when 1 => r := "00100";
                    when 2 => r := "00100";
                    when 3 => r := "00100";
                    when 4 => r := "00100";
                    when 5 => r := "00100";
                    when others => r := "00100";
                end case;
            when 85 => -- 'U'
                case row is
                    when 0 => r := "10001";
                    when 1 => r := "10001";
                    when 2 => r := "10001";
                    when 3 => r := "10001";
                    when 4 => r := "10001";
                    when 5 => r := "10001";
                    when others => r := "01110";
                end case;
            when 86 => -- 'V'
                case row is
                    when 0 => r := "10001";
                    when 1 => r := "10001";
                    when 2 => r := "10001";
                    when 3 => r := "10001";
                    when 4 => r := "10001";
                    when 5 => r := "01010";
                    when others => r := "00100";
                end case;
            when 87 => -- 'W'
                case row is
                    when 0 => r := "10001";
                    when 1 => r := "10001";
                    when 2 => r := "10001";
                    when 3 => r := "10101";
                    when 4 => r := "10101";
                    when 5 => r := "10101";
                    when others => r := "01010";
                end case;
            when 88 => -- 'X'
                case row is
                    when 0 => r := "10001";
                    when 1 => r := "10001";
                    when 2 => r := "01010";
                    when 3 => r := "00100";
                    when 4 => r := "01010";
                    when 5 => r := "10001";
                    when others => r := "10001";
                end case;
            when 89 => -- 'Y'
                case row is
                    when 0 => r := "10001";
                    when 1 => r := "10001";
                    when 2 => r := "01010";
                    when 3 => r := "00100";
                    when 4 => r := "00100";
                    when 5 => r := "00100";
                    when others => r := "00100";
                end case;
            when 90 => -- 'Z'
                case row is
                    when 0 => r := "11111";
                    when 1 => r := "00001";
                    when 2 => r := "00010";
                    when 3 => r := "00100";
                    when 4 => r := "01000";
                    when 5 => r := "10000";
                    when others => r := "11111";
                end case;

            when others =>
                r := "00000";
        end case;

        return r;
    end function;

    function test_name_char(test_id : std_logic_vector(7 downto 0); pos : integer) return std_logic_vector is
        variable id : integer := to_integer(unsigned(test_id));
        variable c  : integer := 32; -- ' '
        variable name : int5_t := (others => 32); -- ' '
    begin
        case id is
            when 16#01# => name := (76, 68, 73, 32, 32); -- LDI
            when 16#02# => name := (77, 86, 32, 32, 32); -- MV
            when 16#03# => name := (65, 68, 68, 32, 32); -- ADD
            when 16#04# => name := (83, 85, 66, 32, 32); -- SUB
            when 16#05# => name := (65, 68, 68, 73, 32); -- ADDI
            when 16#06# => name := (65, 68, 68, 73, 45); -- ADDI-
            when 16#07# => name := (65, 78, 68, 32, 32); -- AND
            when 16#08# => name := (79, 82, 32, 32, 32); -- OR
            when 16#09# => name := (88, 79, 82, 32, 32); -- XOR
            when 16#0A# => name := (65, 78, 68, 73, 32); -- ANDI
            when 16#0B# => name := (79, 82, 73, 32, 32); -- ORI
            when 16#0C# => name := (88, 79, 82, 73, 32); -- XORI
            when 16#0D# => name := (83, 72, 76, 32, 32); -- SHL
            when 16#0E# => name := (83, 72, 82, 32, 32); -- SHR
            when 16#0F# => name := (83, 65, 82, 32, 32); -- SAR
            when 16#10# => name := (82, 48, 32, 32, 32); -- R0
            when 16#11# => name := (76, 68, 83, 84, 32); -- LDST
            when 16#12# => name := (76, 68, 88, 32, 32); -- LDX
            when 16#13# => name := (66, 82, 67, 72, 32); -- BRCH
            when 16#FF# => name := (65, 76, 76, 32, 32); -- ALL
            when others => name := (85, 78, 75, 78, 32); -- UNKN
        end case;

        if pos >= 0 and pos <= 4 then
            c := name(pos);
        end if;
        return std_logic_vector(to_unsigned(c, 8));
    end function;

    function line0_char(status : std_logic_vector(15 downto 0); pos : integer) return std_logic_vector is
        variable test_id : std_logic_vector(7 downto 0) := status(15 downto 8);
        variable hi : unsigned(3 downto 0) := unsigned(test_id(7 downto 4));
        variable lo : unsigned(3 downto 0) := unsigned(test_id(3 downto 0));
    begin
        case pos is
            when 0 => return x"54"; -- 'T'
            when 1 => return hex_nibble_to_ascii(hi);
            when 2 => return hex_nibble_to_ascii(lo);
            when 3 => return x"20"; -- ' '
            when 4 | 5 | 6 | 7 | 8 => return test_name_char(test_id, pos - 4);
            when others => return x"20"; -- ' '
        end case;
    end function;

    function line1_char(status : std_logic_vector(15 downto 0); pos : integer) return std_logic_vector is
        variable state : std_logic_vector(1 downto 0) := status(1 downto 0);
        variable txt : integer := 32; -- ' '
        variable w : int5_t := (32, 32, 32, 32, 32); -- ' '
    begin
        if state = "00" then
            w := (82, 85, 78, 32, 32); -- RUN
        elsif state = "01" then
            w := (80, 65, 83, 83, 32); -- PASS
        elsif state = "10" then
            w := (70, 65, 73, 76, 32); -- FAIL
        else
            w := (45, 45, 45, 45, 32); -- ----
        end if;

        if pos >= 0 and pos <= 4 then
            txt := w(pos);
        end if;
        return std_logic_vector(to_unsigned(txt, 8));
    end function;

    function osd_pixel(i : integer; base_pixel : std_logic_vector(15 downto 0); status : std_logic_vector(15 downto 0)) return std_logic_vector is
        variable x : integer;
        variable y : integer;
        variable bg : std_logic_vector(15 downto 0);
        variable fg : std_logic_vector(15 downto 0);
        variable state : std_logic_vector(1 downto 0) := status(1 downto 0);
        constant x0 : integer := 2;
        constant cell_w : integer := 6; -- 5 pixels + 1 spacing
        constant line0_y : integer := 1;
        constant line1_y : integer := 9;
        variable in_glyph : boolean := false;
        variable which_line : integer := 0;
        variable row_in_glyph : integer := 0;
        variable col_in_cell : integer := 0;
        variable char_idx : integer := 0;
        variable c : std_logic_vector(7 downto 0) := (others => '0');
        variable bits : std_logic_vector(4 downto 0);
        variable col : integer := 0;
    begin
        x := i mod WIDTH;
        y := i / WIDTH;

        if y >= 0 and y < OSD_HEIGHT then
            if state = "10" then
                bg := x"F800"; -- red
                fg := x"FFFF"; -- white text on red
            elsif state = "01" then
                bg := x"07E0"; -- green
                fg := x"0000"; -- black
            else
                bg := x"FFE0"; -- yellow
                fg := x"0000"; -- black
            end if;

            if x >= x0 then
                col_in_cell := (x - x0) mod cell_w;
                char_idx := (x - x0) / cell_w;

                if col_in_cell <= 4 then
                    if y >= line0_y and y < line0_y + 7 then
                        which_line := 0;
                        row_in_glyph := y - line0_y;
                        in_glyph := true;
                    elsif y >= line1_y and y < line1_y + 7 then
                        which_line := 1;
                        row_in_glyph := y - line1_y;
                        in_glyph := true;
                    end if;

                    if in_glyph then
                        if which_line = 0 then
                            c := line0_char(status, char_idx);
                        else
                            c := line1_char(status, char_idx);
                        end if;

                        bits := glyph_row_5x7(c, row_in_glyph);
                        col := col_in_cell;
                        if bits(4 - col) = '1' then
                            return fg;
                        end if;
                    end if;
                end if;
            end if;

            return bg;
        end if;

        return base_pixel;
    end function;

    function pattern_rgb565(i : integer) return std_logic_vector is
        variable x   : integer;
        variable bar : integer;
    begin
        x := i mod WIDTH;
        bar := x / 16; -- 0..7 across 128 pixels
        case bar is
            when 0 => return x"F800"; -- red
            when 1 => return x"07E0"; -- green
            when 2 => return x"001F"; -- blue
            when 3 => return x"FFE0"; -- yellow
            when 4 => return x"F81F"; -- magenta
            when 5 => return x"07FF"; -- cyan
            when 6 => return x"FFFF"; -- white
            when others => return x"0000"; -- black
        end case;
    end function;

begin
    fb_addr <= fb_addr_r;

    tft_cs_n    <= cs_n_r;
    tft_dc      <= dc_r;
    tft_reset_n <= reset_n_r;
    tft_sck     <= spi_sck_r;
    tft_mosi    <= spi_mosi_r;

    -- ================================================================
    -- SPI byte sender (Mode 0): data changes on falling edge, sampled
    -- on rising edge.
    -- ================================================================
    spi_proc: process(clk, rst)
    begin
        if rst = '1' then
            spi_busy    <= '0';
            spi_done    <= '0';
            spi_sck_r   <= '0';
            spi_mosi_r  <= '0';
            spi_div_cnt <= 0;
            spi_bit_idx <= 7;
            spi_shift   <= (others => '0');
        elsif rising_edge(clk) then
            spi_done <= '0';

            if spi_start = '1' and spi_busy = '0' then
                spi_busy    <= '1';
                spi_sck_r   <= '0';
                spi_div_cnt <= 0;
                spi_shift   <= spi_byte;
                spi_bit_idx <= 7;
                spi_mosi_r  <= spi_byte(7);
            elsif spi_busy = '1' then
                if spi_div_cnt = SPI_DIV - 1 then
                    spi_div_cnt <= 0;

                    if spi_sck_r = '1' then
                        -- Falling edge: advance to next bit
                        spi_sck_r <= '0';
                        if spi_bit_idx = 0 then
                            spi_busy <= '0';
                            spi_done <= '1';
                        else
                            spi_bit_idx <= spi_bit_idx - 1;
                            spi_mosi_r <= spi_shift(spi_bit_idx - 1);
                        end if;
                    else
                        -- Rising edge
                        spi_sck_r <= '1';
                    end if;
                else
                    spi_div_cnt <= spi_div_cnt + 1;
                end if;
            end if;
        end if;
    end process spi_proc;

    -- ================================================================
    -- TFT init + refresh state machine
    -- ================================================================
    fsm_proc: process(clk, rst)
        procedure queue_byte(dc : std_logic; b : std_logic_vector(7 downto 0); next_state : state_type) is
        begin
            spi_byte <= b;
            spi_start <= '1';
            dc_r     <= dc;
            cs_n_r   <= '0';
            after_spi_state <= next_state;
            state <= S_WAIT_SPI;
        end procedure;
    begin
        if rst = '1' then
            state <= S_RESET_LOW;
            reset_n_r <= '0';
            cs_n_r <= '1';
            dc_r <= '0';
            spi_start <= '0';
            delay_cnt <= (others => '0');
            fb_addr_r <= (others => '0');
            pixel_idx <= 0;
            pixel_reg <= (others => '0');
            use_fb_latched <= '0';
            osd_status_latched <= (others => '0');
        elsif rising_edge(clk) then
            spi_start <= '0';

            if delay_cnt /= 0 then
                delay_cnt <= delay_cnt - 1;
            end if;

            case state is
                when S_RESET_LOW =>
                    reset_n_r <= '0';
                    cs_n_r <= '1';
                    dc_r <= '0';
                    delay_cnt <= to_unsigned(10 * CYCLES_PER_MS, delay_cnt'length);
                    state <= S_RESET_WAIT;

                when S_RESET_WAIT =>
                    if delay_cnt = 0 then
                        reset_n_r <= '1';
                        delay_cnt <= to_unsigned(120 * CYCLES_PER_MS, delay_cnt'length);
                        state <= S_INIT_SWRESET;
                    end if;

                when S_WAIT_SPI =>
                    if spi_done = '1' then
                        state <= after_spi_state;
                    end if;

                when S_INIT_SWRESET =>
                    if spi_busy = '0' and delay_cnt = 0 then
                        queue_byte('0', x"01", S_DELAY_150MS); -- SWRESET
                        delay_cnt <= to_unsigned(150 * CYCLES_PER_MS, delay_cnt'length);
                    end if;

                when S_DELAY_150MS =>
                    if delay_cnt = 0 and spi_busy = '0' then
                        state <= S_INIT_SLPOUT;
                    end if;

                when S_INIT_SLPOUT =>
                    if spi_busy = '0' then
                        queue_byte('0', x"11", S_INIT_COLMOD_CMD); -- SLPOUT
                        delay_cnt <= to_unsigned(150 * CYCLES_PER_MS, delay_cnt'length);
                    end if;

                when S_INIT_COLMOD_CMD =>
                    if delay_cnt = 0 and spi_busy = '0' then
                        queue_byte('0', x"3A", S_INIT_COLMOD_DATA); -- COLMOD
                    end if;

                when S_INIT_COLMOD_DATA =>
                    if spi_busy = '0' then
                        queue_byte('1', x"05", S_DELAY_10MS); -- 16-bit color
                        delay_cnt <= to_unsigned(10 * CYCLES_PER_MS, delay_cnt'length);
                    end if;

                when S_DELAY_10MS =>
                    if delay_cnt = 0 and spi_busy = '0' then
                        state <= S_INIT_MADCTL_CMD;
                    end if;

                when S_INIT_MADCTL_CMD =>
                    if spi_busy = '0' then
                        queue_byte('0', x"36", S_INIT_MADCTL_DATA); -- MADCTL
                    end if;

                when S_INIT_MADCTL_DATA =>
                    if spi_busy = '0' then
                        queue_byte('1', x"C8", S_INIT_CASET_CMD); -- row/col exchange + BGR
                    end if;

                when S_INIT_CASET_CMD =>
                    if spi_busy = '0' then
                        queue_byte('0', x"2A", S_INIT_CASET_0); -- CASET
                    end if;
                when S_INIT_CASET_0 =>
                    if spi_busy = '0' then
                        queue_byte('1', x"00", S_INIT_CASET_1);
                    end if;
                when S_INIT_CASET_1 =>
                    if spi_busy = '0' then
                        queue_byte('1', x"00", S_INIT_CASET_2);
                    end if;
                when S_INIT_CASET_2 =>
                    if spi_busy = '0' then
                        queue_byte('1', x"00", S_INIT_CASET_3);
                    end if;
                when S_INIT_CASET_3 =>
                    if spi_busy = '0' then
                        queue_byte('1', std_logic_vector(to_unsigned(WIDTH - 1, 8)), S_INIT_RASET_CMD);
                    end if;

                when S_INIT_RASET_CMD =>
                    if spi_busy = '0' then
                        queue_byte('0', x"2B", S_INIT_RASET_0); -- RASET
                    end if;
                when S_INIT_RASET_0 =>
                    if spi_busy = '0' then
                        queue_byte('1', x"00", S_INIT_RASET_1);
                    end if;
                when S_INIT_RASET_1 =>
                    if spi_busy = '0' then
                        queue_byte('1', x"00", S_INIT_RASET_2);
                    end if;
                when S_INIT_RASET_2 =>
                    if spi_busy = '0' then
                        queue_byte('1', x"00", S_INIT_RASET_3);
                    end if;
                when S_INIT_RASET_3 =>
                    if spi_busy = '0' then
                        queue_byte('1', std_logic_vector(to_unsigned(HEIGHT - 1, 8)), S_INIT_NORON);
                    end if;

                when S_INIT_NORON =>
                    if spi_busy = '0' then
                        queue_byte('0', x"13", S_INIT_DISPON); -- NORON
                        delay_cnt <= to_unsigned(10 * CYCLES_PER_MS, delay_cnt'length);
                    end if;

                when S_INIT_DISPON =>
                    if delay_cnt = 0 and spi_busy = '0' then
                        queue_byte('0', x"29", S_DELAY_100MS); -- DISPON
                        delay_cnt <= to_unsigned(100 * CYCLES_PER_MS, delay_cnt'length);
                    end if;

                when S_DELAY_100MS =>
                    if delay_cnt = 0 and spi_busy = '0' then
                        pixel_idx <= 0;
                        use_fb_latched <= use_fb;
                        osd_status_latched <= osd_status;
                        state <= S_FRAME_RAMWR;
                    end if;

                when S_FRAME_RAMWR =>
                    if spi_busy = '0' then
                        queue_byte('0', x"2C", S_PIXEL_SET_ADDR); -- RAMWR
                    end if;

                when S_PIXEL_SET_ADDR =>
                    fb_addr_r <= to_unsigned(pixel_idx, fb_addr_r'length);
                    state <= S_PIXEL_WAIT;

                when S_PIXEL_WAIT =>
                    state <= S_PIXEL_LATCH;

                when S_PIXEL_LATCH =>
                    if use_fb_latched = '1' then
                        pixel_reg <= osd_pixel(pixel_idx, fb_data, osd_status_latched);
                    else
                        pixel_reg <= osd_pixel(pixel_idx, pattern_rgb565(pixel_idx), osd_status_latched);
                    end if;
                    state <= S_PIXEL_SEND_MSB;

                when S_PIXEL_SEND_MSB =>
                    if spi_busy = '0' then
                        queue_byte('1', pixel_reg(15 downto 8), S_PIXEL_SEND_LSB);
                    end if;

                when S_PIXEL_SEND_LSB =>
                    if spi_busy = '0' then
                        queue_byte('1', pixel_reg(7 downto 0), S_PIXEL_SET_ADDR);
                        if pixel_idx = PIXELS - 1 then
                            pixel_idx <= 0;
                            use_fb_latched <= use_fb;
                            osd_status_latched <= osd_status;
                            after_spi_state <= S_FRAME_RAMWR;
                        else
                            pixel_idx <= pixel_idx + 1;
                            after_spi_state <= S_PIXEL_SET_ADDR;
                        end if;
                    end if;
            end case;
        end if;
    end process fsm_proc;

end architecture;
