----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 26.02.2020 11:04:29
-- Design Name: 
-- Module Name: 
-- Project Name: 10615291.vhd
-- Target Devices: 
-- Tool Versions: 
-- Description: Prova finale di Reti Logiche - Prof. Gianluca Palermo - anno 2019/2020
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity project_reti_logiche is
    port ( 
        i_clk       : in  std_logic; 
        i_start     : in  std_logic; 
        i_rst       : in  std_logic; 
        i_data      : in  std_logic_vector(7 downto 0);  
        o_address   : out std_logic_vector(15 downto 0); 
        o_done      : out std_logic; 
        o_en        : out std_logic; 
        o_we        : out std_logic; 
        o_data      : out std_logic_vector (7 downto 0) 
    );
end project_reti_logiche;


architecture Behavioral of project_reti_logiche is

type state_type is (IDLE, SALV, PRESET, C_WZ0, C_WZ1, C_WZ2, C_WZ3, C_WZ4, C_WZ5, C_WZ6, C_WZ7, FINE);
signal next_state, current_state : state_type;

signal indirizzo, indirizzo_next : std_logic_vector (7 downto 0) := "00000000";
signal o_en_next : std_logic := '0';
signal o_we_next : std_logic := '0';
signal o_done_next : std_logic := '0';
signal o_data_next : std_logic_vector (7 downto 0) := "00000000";
signal o_address_next : std_logic_vector (15 downto 0) := "0000000000000000";

begin

 --ci� che faccio �: se ho un segnale di reset, mi porto in IDLE, dove aspetter� il segnale di start.
 --altrimenti, ad ogni ciclo di clock, lo stato cambia sulla salita del clock.
 --Sulla salita del clock ho anche la ricezione del dato dalla RAM, in base all'indirizzo inviato a quest'ultima.
 reg : process(i_clk, i_rst)
 begin
    if i_rst = '1' then
    
       current_state <= IDLE;
       indirizzo <= (others => '0' );
       
    elsif i_rst = '0' and rising_edge(i_clk) then
    
        current_state <= next_state;
        indirizzo <= indirizzo_next;
        o_en <= o_en_next;
        o_we <= o_we_next;
        o_done <= o_done_next;
        o_data <= o_data_next;
        o_address <= o_address_next;
        
    end if;
 end process;
    
 --lambda_delta: funzione che definisce lo stato successivo e l'output
 lambda_delta : process(current_state, i_start, i_data, indirizzo)
 
 variable datosalvato : std_logic_vector (7 downto 0) := "00000000";
 
 begin
 
    case current_state is
        
        --IDLE: stato in cui aspetto lo start a 1
        --"Il modulo partir� nella elaborazione quando un segnale START in ingresso verr� portato a 1"
        --quando lo start viene messo a 1, parte l'esecuzione. 
        --1. Attivo enable, per attivare lo scambio di informazioni tra il mio componente e la memoria. 
        --2. Chiedo alla RAM l'elemento in posizione 8, che � l'indirizzo da codificare
        --3. Passo nello stato SALV, per inizializzare "indirizzo"
        when IDLE =>
        
            if i_start = '1' then 
                o_en_next <= '1';
                o_address_next <= "0000000000001000"; --o_address_next � 8, cio� "0000 0000 0000 1000"
                next_state <= SALV;  
                
                --valori di default
                o_done_next <= '0';
                o_we_next <= '0';
                o_data_next <= "00000000";
                
                indirizzo_next <= "00000000"; 
                
            --else per prevenire l'utilizzo di latch    
            --else: caso in cui start non sia 1. Devo ritornare in IDLE
            else
                o_en_next <= '1';
                o_address_next <= "0000000000001000";
                next_state <= IDLE;
                
                o_done_next <= '0';
                o_we_next <= '0';
                o_data_next <= "00000000";
                
                indirizzo_next <= "00000000"; 
                
            end if;
            
        when SALV =>
            
            indirizzo_next <= "00000000";
            
            o_address_next <= "0000000000000000";  --o_address_next � 0, cio� "0000 0000 0000 0000", poich� tra due stati ho C_WZ0, dove confronto con la WZ0
                                                   
            next_state <= PRESET;
            
            o_en_next <= '1';
            o_we_next <= '0';
            o_done_next <= '0';
            o_data_next <= "00000000";

            
        --1. Salvo nel segnale "indirizzo" l'elemento in posizione 8 della RAM, cio� l'indirizzo da codificare
        --2. Chiedo alla RAM o_address_next = '1', cio� la base della seconda WZ
        --3. Vado nello stato C_WZO per iniziare i confronti
        when PRESET =>
        
            indirizzo_next <= i_data;
        
            o_address_next <= "0000000000000001";  --o_address_next � 1, cioé "0000 0000 0000 0001", poiché tra due stati ho C_WZ1, dove confronto con la WZ1
            next_state <= C_WZ0;
            
            o_en_next <= '1';
            o_we_next <= '0';
            o_done_next <= '0';
            o_data_next <= "00000000";
                        
        -- Qui iniziano tutti i confronti.
        -- Se "indirizzo" è uguale al dato che arriva dalla memoria, vuol dire che l'indirizzo da codificare è 
        -- la base della WZ presa in considerazione.
        -- Dopodiché si testano anche, uno per uno, i tre elementi successivi, e
        -- a) Se si trova il confronto bene, attivo o_we_next e scrivo nella posizione 9 della RAM la codifica, con   
        -- WZ_BIT = '1' & WZ_NUM & WZ_OFFSET, dopodiché vado nello stato finale FINE
        -- b) Se nessun confronto risulta valido, chiedo alla RAM l'indirizzo base della WZ successiva.
        -- Questo per tutti gli stati tranne per C_WZ7, che è l'ultimo, per il quale, se non si trova nessun confronto,
        -- si può essere certi che l'indirizzo non appartiene a nessuna WZ, e per questo motivo si risputa l'indirizzo 
        -- come WZ_BIT = '0' & indirizzo 
        when C_WZ0 =>           
        
            datosalvato := i_data; 
                
            if indirizzo = datosalvato then
                o_we_next <= '1';
                o_address_next <= "0000000000001001"; --o_address_next è 9, dove devo scrivere, cioé "0000 0000 0000 1001"
                o_data_next <= "10000001"; --offset one-hot di 0: "1 000 0001"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';
                
                
                indirizzo_next <= indirizzo;
                
            elsif to_integer(unsigned(indirizzo)) = to_integer(unsigned(datosalvato)) + 1 then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "10000010"; --offset one-hot di 1: "1 000 0010"
                next_state <= FINE;  
                
                o_en_next <= '1';
                o_done_next <= '1';
                
                
                indirizzo_next <= indirizzo;
                
            elsif to_integer(unsigned(indirizzo)) = to_integer(unsigned(datosalvato)) + 2 then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "10000100"; --offset one-hot di 2: "1 000 0100"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';       
                
                
                indirizzo_next <= indirizzo;          
                
            elsif to_integer(unsigned(indirizzo)) = to_integer(unsigned(datosalvato)) + 3 then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "10001000"; --offset one-hot di 3: "1 000 1000"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';       
                
                
                indirizzo_next <= indirizzo;          
                
            else
                o_address_next <= "0000000000000010"; --o_address_next è 2, cioé "0000 0000 0000 0010", poiché tra due stati ho C_WZ2, dove confronto con la WZ2
                next_state <= C_WZ1;
                
                --per evitare inferring latch
                o_we_next <= '0';
                o_data_next <= "00000000";
                
                o_en_next <= '1';
                o_done_next <= '0';
                
                
                indirizzo_next <= indirizzo;
                
            end if;
  
        when C_WZ1 =>
        
            datosalvato := i_data; 
        
            if indirizzo = datosalvato then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "10010001"; --"1 001 0001"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';        
                
                
                indirizzo_next <= indirizzo;         
       
            elsif to_integer(unsigned(indirizzo)) = to_integer(unsigned(datosalvato)) + 1 then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "10010010"; --"1 001 0010"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';       
                
                
                indirizzo_next <= indirizzo;          
                
            elsif to_integer(unsigned(indirizzo)) = to_integer(unsigned(datosalvato)) + 2 then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "10010100"; --"1 001 0100"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1'; 
                
                
                indirizzo_next <= indirizzo;                
                
            elsif to_integer(unsigned(indirizzo)) = to_integer(unsigned(datosalvato)) + 3 then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "10011000"; --"1 001 1000"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';   
                
                
                indirizzo_next <= indirizzo;              
                
            else
                o_address_next <= "0000000000000011"; --o_address_next è 3, cioé "0000 0000 0000 0011", poiché tra due stati ho C_WZ3, dove confronto con la WZ3
                next_state <= C_WZ2;
                
                --per evitare inferring latch
                o_we_next <= '0';
                o_data_next <= "00000000";
                
                o_en_next <= '1';
                o_done_next <= '0';
                
                
                indirizzo_next <= indirizzo;
                
            end if;
                   
        when C_WZ2 =>
        
            datosalvato :=  i_data; 
            
            if indirizzo = datosalvato then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "10100001"; --"1 010 0001"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';        
                
                
                indirizzo_next <= indirizzo;         
                
            elsif to_integer(unsigned(indirizzo)) = to_integer(unsigned(datosalvato)) + 1 then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "10100010"; --"1 010 0010"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';              
                
                
                indirizzo_next <= indirizzo;   
                
            elsif to_integer(unsigned(indirizzo)) = to_integer(unsigned(datosalvato)) + 2 then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "10100100"; --"1 010 0100"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';         
                
                
                indirizzo_next <= indirizzo;        
                
            elsif to_integer(unsigned(indirizzo)) = to_integer(unsigned(datosalvato)) + 3 then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "10101000"; --"1 010 1000"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';    
                
                
                indirizzo_next <= indirizzo;             
                
            else
                o_address_next <= "0000000000000100"; --o_address_next è 4, cioé "0000 0000 0000 0100", poiché tra due stati ho C_WZ4, dove confronto con la WZ4
                next_state <= C_WZ3;
                
                --per evitare inferring latch
                o_we_next <= '0';
                o_data_next <= "00000000";
                o_en_next <= '1';
                o_done_next <= '0';
                
                
                indirizzo_next <= indirizzo;
                
            end if;
        
        when C_WZ3 =>
        
            datosalvato :=  i_data; 
            
            if indirizzo = datosalvato then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "10110001"; --"1 011 0001"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';    
                
                
                indirizzo_next <= indirizzo;             
                
            elsif to_integer(unsigned(indirizzo)) = to_integer(unsigned(datosalvato)) + 1 then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "10110010"; --"1 011 0010"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1'; 
                
                
                indirizzo_next <= indirizzo;                
                
            elsif to_integer(unsigned(indirizzo)) = to_integer(unsigned(datosalvato)) + 2 then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "10110100"; --"1 011 0100"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';         
                
                
                indirizzo_next <= indirizzo;        
                
            elsif to_integer(unsigned(indirizzo)) = to_integer(unsigned(datosalvato)) + 3 then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "10111000"; --"1 011 1000"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';     
                
                
                indirizzo_next <= indirizzo;            
                
            else
                o_address_next <= "0000000000000101"; --o_address_next è 5, cioé "0000 0000 0000 0101", poiché tra due stati ho C_WZ5, dove confronto con la WZ5
                next_state <= C_WZ4;
                
                --per evitare inferring latch
                o_we_next <= '0';
                o_data_next <= "00000000";
                o_en_next <= '1';
                o_done_next <= '0';
                
                
                indirizzo_next <= indirizzo;
   
            end if;
        
        
        when C_WZ4 =>
        
            datosalvato :=  i_data; 
        
            if indirizzo = datosalvato then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "11000001"; --"1 100 0001"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';   
                
                indirizzo_next <= indirizzo;              
                
            elsif to_integer(unsigned(indirizzo)) = to_integer(unsigned(datosalvato)) + 1 then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "11000010";--"1 100 0010"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';   
                
                indirizzo_next <= indirizzo;              
                
            elsif to_integer(unsigned(indirizzo)) = to_integer(unsigned(datosalvato)) + 2 then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "11000100"; --"1 100 0100"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';     
                
                indirizzo_next <= indirizzo;            
                
            elsif to_integer(unsigned(indirizzo)) = to_integer(unsigned(datosalvato)) + 3 then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "11001000"; --"1 100 1000"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';      
                
                
                indirizzo_next <= indirizzo;           
                
            else
                o_address_next <= "0000000000000110"; --o_address_next è 6, cioé "0000 0000 0000 0110", poiché tra due stati ho C_WZ6, dove confronto con la WZ6
                next_state <= C_WZ5;
                
                --per evitare inferring latch
                o_we_next <= '0';
                o_data_next <= "00000000";
                o_en_next <= '1';
                o_done_next <= '0';
                
                
                indirizzo_next <= indirizzo;
                
            end if;
        
        when C_WZ5 =>
        
            datosalvato :=  i_data; 
            
            if indirizzo = datosalvato then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "11010001"; --"1 101 0001"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';  
                
                
                indirizzo_next <= indirizzo;               
                
            elsif to_integer(unsigned(indirizzo)) = to_integer(unsigned(datosalvato)) + 1 then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "11010010"; --"1 101 0010"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';   
                
                
                indirizzo_next <= indirizzo;              
                
            elsif to_integer(unsigned(indirizzo)) = to_integer(unsigned(datosalvato)) + 2 then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "11010100"; --"1 101 0100"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';    
                
                
                indirizzo_next <= indirizzo;             

            elsif to_integer(unsigned(indirizzo)) = to_integer(unsigned(datosalvato)) + 3 then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "11011000"; --"1 101 1000"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';   
                
                
                indirizzo_next <= indirizzo;              
                
            else
                o_address_next <= "0000000000000111"; --o_address_next è 7, cioé "0000 0000 0000 0111", poiché tra due stati ho C_WZ7, dove confronto con la WZ7
                next_state <= C_WZ6;
                
                --per evitare inferring latch
                o_we_next <= '0';
                o_data_next <= "00000000";
                o_en_next <= '1';
                o_done_next <= '0';
                
                
                indirizzo_next <= indirizzo;
   
            end if;
        
        
        when C_WZ6 =>
        
            datosalvato :=  i_data; 
            
            if indirizzo = datosalvato then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "11100001"; --"1 110 0001"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';   
           
                
                indirizzo_next <= indirizzo;              

            elsif to_integer(unsigned(indirizzo)) = to_integer(unsigned(datosalvato)) + 1 then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "11100010"; --1 110 0010"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';     
                
                
                indirizzo_next <= indirizzo;            

            elsif to_integer(unsigned(indirizzo)) = to_integer(unsigned(datosalvato)) + 2 then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "11100100"; --"1 110 0100"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';  
                
                
                indirizzo_next <= indirizzo;
                              
            elsif to_integer(unsigned(indirizzo)) = to_integer(unsigned(datosalvato)) + 3 then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "11101000"; --1 110 1000"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';     
                
                
                indirizzo_next <= indirizzo;            
                
            else
                o_address_next <= "0000000000001001"; --o_address_next è 9, cioé "0000 0000 0000 1001", poiché tra due stati sono in FINE
                next_state <= C_WZ7;
                
                --per evitare inferring latch
                o_we_next <= '0';
                o_data_next <= "00000000";
                o_en_next <= '1';
                o_done_next <= '0';
                
                
                indirizzo_next <= indirizzo;
                
            end if;        
        
        when C_WZ7 =>
        
            datosalvato :=  i_data; 
            
            if indirizzo = datosalvato then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "11110001"; --"1 111 0001"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';    
                
                
                indirizzo_next <= indirizzo;             
 
            elsif to_integer(unsigned(indirizzo)) = to_integer(unsigned(datosalvato)) + 1 then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "11110010"; --"1 111 0010"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';    
                
                
                indirizzo_next <= indirizzo;             

            elsif to_integer(unsigned(indirizzo)) = to_integer(unsigned(datosalvato)) + 2 then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "11110100"; --"1 111 0100"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';  
                
                
                indirizzo_next <= indirizzo;               

            elsif to_integer(unsigned(indirizzo)) = to_integer(unsigned(datosalvato)) + 3 then
                o_we_next <= '1';
                o_address_next <= "0000000000001001";
                o_data_next <= "11111000"; --"1 111 1000"
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';   
                
                
                indirizzo_next <= indirizzo;              

            else
                o_we_next <= '1';
                o_address_next <= "0000000000001001"; --o_address_next è 9, cioé "0000 0000 0000 1001", poiché tra due stati resto in FINE
                o_data_next <= indirizzo; --ciò che devo scrivere è l'indirizzo ricevuto in partenza
                next_state <= FINE;
                
                o_en_next <= '1';
                o_done_next <= '1';   
                
                
                indirizzo_next <= indirizzo;              

            end if;      
            
            
        -- "Il segnale di START rimarrà alto fino a che il segnale di DONE non verrà portato alto; 
        -- Al termine della computazione (e una volta scritto il risultato in memoria), 
        -- il modulo da progettare deve alzare (portare a 1) il segnale DONE che notifica la fine dell’elaborazione"    
            
        when FINE =>
              
              -- Il segnale DONE deve rimanere alto fino a che il segnale di START non è riportato a 0. 
                if i_start = '0' then
                  o_done_next <= '0';
                  o_address_next <= "0000000000000000";
                  
                  o_en_next <= '0';
                  o_we_next <= '0';
                  o_data_next <= "00000000";
                  
                  
                  indirizzo_next <= indirizzo;
                  
                  next_state <= IDLE;
                else 
                  o_done_next <= '1';
                  o_address_next <= "0000000000001001";
                  
                  o_en_next <= '0';
                  o_we_next <= '0';
                  o_data_next <= "00000000";
                  
                  indirizzo_next <= indirizzo;
                  
                  next_state <= FINE;          
              end if;   
              
              
        end case;
    end process;
end Behavioral;
