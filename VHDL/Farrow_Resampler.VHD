library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity farrow_resampler_iq is
port (
    clk         : in std_logic;
    rst         : in std_logic;

    -- Input interface
    din_i       : in signed(15 downto 0);     -- I input
    din_q       : in signed(15 downto 0);     -- Q input
    din_valid   : in std_logic;               -- Input valid strobe

    -- Phase increment from external controller
    phase_inc   : in unsigned(31 downto 0);   -- Controlled externally

    -- Output interface
    dout_i      : out signed(15 downto 0);    -- Interpolated I output
    dout_q      : out signed(15 downto 0);    -- Interpolated Q output
    dout_valid  : out std_logic              -- Output valid strobe
);
end entity;
architecture Behavioral of farrow_resampler_iq is

    constant INPUT_WIDTH : integer := 16;
    constant PHASE_WIDTH : integer := 32;

    type reg_array_t is array (0 to 3) of signed(INPUT_WIDTH-1 downto 0);

    -- Input history registers for I and Q
    signal i_reg, q_reg       : reg_array_t := (others => (others => '0'));
    signal x_valid            : std_logic_vector(3 downto 0) := (others => '0');

    -- Fractional delay calculation
    signal phase_acc          : unsigned(PHASE_WIDTH-1 downto 0) := (others => '0');
    signal mu                 : signed(PHASE_WIDTH-1 downto 0) := (others => '0');
    signal mu_squared         : signed(2*PHASE_WIDTH-1 downto 0) := (others => '0');
    signal mu_cubed           : signed(3*PHASE_WIDTH-1 downto 0) := (others => '0');

    -- Farrow filter outputs for I and Q
    signal d0_i, d1_i, d2_i, d3_i : signed(47 downto 0) := (others => '0');
    signal d0_q, d1_q, d2_q, d3_q : signed(47 downto 0) := (others => '0');

    -- Multiply terms
    signal term1_i, term2_i, term3_i, term4_i : signed(47 downto 0) := (others => '0');
    signal term1_q, term2_q, term3_q, term4_q : signed(47 downto 0) := (others => '0');

    signal y_unscaled_i, y_unscaled_q : signed(49 downto 0) := (others => '0');
    signal y_scaled_i, y_scaled_q     : signed(18 downto 0) := (others => '0');

    -- Previous MSB for output valid detection
    signal prev_msb : std_logic := '0';

begin

    -- Input pipeline and shift register for I and Q
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                i_reg <= (others => (others => '0'));
                q_reg <= (others => (others => '0'));
                x_valid <= (others => '0');
            else
                if din_valid = '1' then
                    i_reg(0) <= din_i;
                    i_reg(1) <= i_reg(0);
                    i_reg(2) <= i_reg(1);
                    i_reg(3) <= i_reg(2);

                    q_reg(0) <= din_q;
                    q_reg(1) <= q_reg(0);
                    q_reg(2) <= q_reg(1);
                    q_reg(3) <= q_reg(2);

                    x_valid <= x_valid(2 downto 0) & '1';
                end if;
            end if;
        end if;
    end process;

    -- Phase accumulator
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                phase_acc <= (others => '0');
            else
                phase_acc <= phase_acc + phase_inc;
            end if;
        end if;
    end process;

    -- Extract mu (fractional part of phase)
    mu <= signed(phase_acc(PHASE_WIDTH-1 downto 0));

    -- Compute mu squared and cubed
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                mu_squared <= (others => '0');
                mu_cubed   <= (others => '0');
            else
                mu_squared <= mu * mu;
                mu_cubed   <= mu_squared * mu;
            end if;
        end if;
    end process;

    -- Farrow subfilters (cubic interpolation) for I and Q
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                d0_i <= (others => '0'); d0_q <= (others => '0');
                d1_i <= (others => '0'); d1_q <= (others => '0');
                d2_i <= (others => '0'); d2_q <= (others => '0');
                d3_i <= (others => '0'); d3_q <= (others => '0');
            else
                d0_i <= resize(i_reg(0), d0_i'length);
                d0_q <= resize(q_reg(0), d0_q'length);

                d1_i <= resize((-i_reg(1) + i_reg(0)) / 2, d1_i'length);
                d1_q <= resize((-q_reg(1) + q_reg(0)) / 2, d1_q'length);

                d2_i <= resize(i_reg(0) - (i_reg(1)*to_signed(5, 3))/2 + i_reg(2) - i_reg(3)/2, d2_i'length);
                d2_q <= resize(q_reg(0) - (q_reg(1)*to_signed(5, 3))/2 + q_reg(2) - q_reg(3)/2, d2_q'length);

                d3_i <= resize((-i_reg(0) + i_reg(1)*3 - i_reg(2)*3 + i_reg(3)) / 2, d3_i'length);
                d3_q <= resize((-q_reg(0) + q_reg(1)*3 - q_reg(2)*3 + q_reg(3)) / 2, d3_q'length);
            end if;
        end if;
    end process;

    -- Multiply by mu^n
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                term1_i <= (others => '0'); term1_q <= (others => '0');
                term2_i <= (others => '0'); term2_q <= (others => '0');
                term3_i <= (others => '0'); term3_q <= (others => '0');
                term4_i <= (others => '0'); term4_q <= (others => '0');
            else
                term1_i <= d0_i; term1_q <= d0_q;
                term2_i <= d1_i * mu; term2_q <= d1_q * mu;
                term3_i <= d2_i * mu_squared; term3_q <= d2_q * mu_squared;
                term4_i <= d3_i * mu_cubed; term4_q <= d3_q * mu_cubed;
            end if;
        end if;
    end process;

    -- Combine all terms
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                y_unscaled_i <= (others => '0');
                y_unscaled_q <= (others => '0');
            else
                y_unscaled_i <= term1_i + term2_i + term3_i + term4_i;
                y_unscaled_q <= term1_q + term2_q + term3_q + term4_q;
            end if;
        end if;
    end process;

    -- Scale back to 16-bit output
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                y_scaled_i <= (others => '0');
                y_scaled_q <= (others => '0');
            else
                y_scaled_i <= resize(y_unscaled_i(y_unscaled_i'high downto 16), y_scaled_i'length);
                y_scaled_q <= resize(y_unscaled_q(y_unscaled_q'high downto 16), y_scaled_q'length);
            end if;
        end if;
    end process;

    -- Output valid logic based on phase accumulator MSB change
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                dout_i <= (others => '0');
                dout_q <= (others => '0');
                dout_valid <= '0';
                prev_msb <= '0';
            else
                if phase_acc(31) /= prev_msb then
                    dout_i <= y_scaled_i(18 downto 3);
                    dout_q <= y_scaled_q(18 downto 3);
                    dout_valid <= x_valid(3); -- Only valid if enough data
                    prev_msb <= phase_acc(31);
                else
                    dout_valid <= '0';
                end if;
            end if;
        end if;
    end process;

end architecture;