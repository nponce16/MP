--
-- Copyright (c) 2017 XXXX, UPC
-- All rights reserved.
-- 

library ieee;
use ieee.std_logic_1164.all;

use work.param_disenyo_pkg.all;
use work.controlador_pkg.all;
use work.retardos_controlador_pkg.all;
use work.acciones_pkg.all;
use work.procedimientos_controlador_pkg.all;
--! @image html controlador.png

entity controlador is
port (reloj, pcero: in std_logic;
pet: in tp_contro_e;
s_estado: in tp_contro_cam_estado;
s_control: out tp_contro_cam_cntl;
resp: out tp_contro_s;
resp_m: in tp_cntl_memoria_e;
pet_m: out tp_cntl_memoria_s);
end;
 
architecture compor of controlador is

--type tipoestado is (DES0, DES, CMPETIQ, INI, ESCINI, LEC, PML, PMEA, PMEF, ESPL, ESPEA, ESPEF, ESB, ESCP, HECHOL, HECHOE);
signal estado, prxestado: tipoestado;

signal derechos_acceso: std_logic;
     
begin
-- determinacion de los derechos de acceso al bloque
derechos_acceso <= '1' when (s_estado.AF and s_estado.EST) = '1' else '0';

--registro de estado
process (reloj, pcero)
begin
	if pcero = '1' then
		estado <= DES0;
	else
		if rising_edge(reloj) then
			estado <= prxestado;
		end if;
	end if;
end process;

--logica de proximo estado
process (estado, pcero, pet, s_estado, resp_m)
begin
  case estado is
		when DES0 =>
			-- Si no hay peticion, se mantiene en DES0
			if not hay_peticion_procesador (pet) then
				prxestado <= DES0;
			-- Si hay peticion
			elsif hay_peticion_ini_procesador(pet) then
				resp.listo <= '1';
				prxestado <= INI;
			else
				s_control.EST_acc <= '1';
				s_control.ET_acc  <= '1';
				prxestado <= CMPETIQ;
			end if;

		when INI =>
			prxestado <= ESCINI;

		when ESCINI =>
			s_control.EST_esc <= '1';
			s_control.ET_esc  <= '1';
			s_control.DAT_esc <= '1';
			prxestado <= DES;

		when DES =>
			-- Si hay peticion
			if hay_peticion_procesador (pet) then
 				s_control.EST_acc <= '1';
        s_control.ET_acc  <= '1';
        prxestado <= CMPETIQ;
			else -- si no hay peticion
 				prxestado <= DES;
      end if;

    when CMPETIQ =>
      -- Si tengo una peticion de lectura
      if pet.esc = '0' then
      	if es_acierto_lectura (pet, derechos_acceso) then -- hay acierto
          s_control.DAT_acc <= '1';
          prxestado <= LEC;
        else -- hay fallo
          pet_m.m_pet <= '1';
          prxestado <= PML;
        end if;

      -- Si tengo una peticion de escritura
      else
        if es_acierto_escritura (pet, derechos_acceso) then -- hay acierto
      	  s_control.EST_esc <= '1';
          s_control.EST_acc <= '1';
          pet_m.m_esc  <= '1';
          prxestado <= PMEA;
        else -- hay fallo
          pet_m.m_esc  <= '1';
          prxestado <= PMEF;
        end if;
      end if;

    when LEC =>
      resp.finalizada <= '1';
      prxestado <= HECHOL;

    when HECHOL =>
  	  resp.listo <= '1';
      prxestado <= DES;

    when PML =>
      prxestado <= ESPL;

    when ESPL =>
      if hay_respuesta_memoria (resp_m) then
        s_control.EST_esc <= '1';
        s_control.ET_esc  <= '1';
        s_control.DAT_esc <= '1';
        prxestado <= ESB;
      else
				prxestado <= ESPL;
			end if;

		when ESB =>
			prxestado <= LEC;

    when PMEA =>
      prxestado <= ESPEA;

    when ESPEA =>
			if resp_m.m_val = '1' then
				s_control.EST_esc <= '1';
				s_control.ET_esc  <= '1';
				s_control.DAT_esc <= '1';
				prxestado <= ESCP;
			else
				prxestado <= ESPEA;
			end if;

		when ESCP =>
			prxestado <= HECHOE;

		when PMEF =>
			prxestado <= ESPEF;

		when ESPEF =>
			if resp_m.m_val = '1' then
				resp.finalizada<= '1';
				prxestado <= HECHOE;
			else
				prxestado <= ESPEF;
			end if;

		when HECHOE =>
			resp.listo <= '1';
			prxestado <= DES;

		when others =>
			null;

	end case;
	estado <= prxestado;

end process;

end;
