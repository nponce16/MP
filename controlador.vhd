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

variable v_estado: tipoestado;
begin
	if pcero = '1' then
		v_estado := DES0;
	else
		if rising_edge(reloj) then
			v_estado := prxestado;
		end if;
	end if;
end process;

--logica de proximo estado
process (estado, pcero, pet, s_estado, resp_m)

variable v_prxestado: tipoestado;

begin
	v_prxestado := estado;
	if pcero /= '1' then
		case estado is
			when DES0 =>
				-- Si no hay peticion, se mantiene en DES0
				if not hay_peticion_procesador (pet) then
					v_prxestado := DES0;
				-- Si hay peticion
				elsif hay_peticion_ini_procesador(pet) then
					v_prxestado := INI;
				else
					v_prxestado := CMPETIQ;
				end if;

			when INI =>
				v_prxestado := ESCINI;

			when ESCINI =>
				v_prxestado := HECHOE;

			when DES =>
				-- Si hay peticion
				if hay_peticion_procesador (pet) then
					v_prxestado := CMPETIQ;
				else -- si no hay peticion
					v_prxestado := DES;
				end if;

			when CMPETIQ =>
				-- Si tengo una peticion de lectura
				if pet.esc = '0' then
					if es_acierto_lectura (pet, derechos_acceso) then -- hay acierto
						v_prxestado := LEC;
					else -- hay fallo
						v_prxestado := PML;
					end if;
				else -- Si tengo una peticion de escritura
					if es_acierto_escritura (pet, derechos_acceso) then -- hay acierto
						v_prxestado := PMEA;
					else -- hay fallo
						v_prxestado := PMEF;
					end if;
				end if;

			when LEC =>
				v_prxestado := HECHOL;

			when HECHOL =>
				v_prxestado := DES;

			when PML =>
				v_prxestado := ESPL;

			when ESPL =>
				if hay_respuesta_memoria (resp_m) then
					v_prxestado := ESB;
				else
					v_prxestado := ESPL;
				end if;

			when ESB =>
				v_prxestado := LEC;

			when PMEA =>
				v_prxestado := ESPEA;

			when ESPEA =>
				if hay_respuesta_memoria (resp_m) then
					v_prxestado := ESCP;
				else
					v_prxestado := ESPEA;
				end if;

			when ESCP =>
				v_prxestado := HECHOE;

			when PMEF =>
				v_prxestado := ESPEF;

			when ESPEF =>
				if hay_respuesta_memoria (resp_m) then
					v_prxestado := HECHOE;
				else
					v_prxestado := ESPEF;
				end if;

			when HECHOE =>
				v_prxestado := DES;

			when others =>
				null;

		end case;
	else 
		v_prxestado := DES0;
	end if;

	prxestado <= v_prxestado after retardo_logica_prx_estado;
end process;

-- logica de salida
process (estado, pet, resp_m, derechos_acceso, pcero)

variable v_s_control: tp_contro_cam_cntl;
variable v_resp: tp_contro_s;
variable v_pet_m: tp_cntl_memoria_s;

begin
	-- valores por defecto
	por_defecto(v_s_control, v_pet_m, v_resp);

	if pcero /= '1' then
		case estado is
			when DES0 =>
				interfaces_DES(v_resp); -- cache lista para recibir peticiones
				lectura_etiq_estado(v_s_control); -- habilita el acceso a ET y EST

			when INI =>
				interfaces_en_CURSO(v_resp); -- cache ocupada

			when ESCINI =>
				interfaces_en_CURSO(v_resp); -- cache ocupada
				actualizar_etiqueta(v_s_control); -- actualiza la etiqueta
				actualizar_estado(v_s_control, contenedor_valido);  -- actualiza el estado
				actualizar_dato (v_s_control); -- actualiza el dato

			when DES =>
				interfaces_DES(v_resp); -- cache lista para recibir peticiones
				lectura_etiq_estado(v_s_control); -- habilita el acceso a ET y EST

			when CMPETIQ =>
				interfaces_en_CURSO(v_resp); -- cache ocupada

			when LEC =>
				interfaces_en_CURSO(v_resp); -- cache ocupada
				lectura_datos(v_s_control); -- habilita el acceso a los datos
			
			when HECHOL =>
				interfaces_HECHOL(v_resp); -- respuesta al procesador hecha (lectura)

			when PML =>
				interfaces_en_CURSO(v_resp); -- cache ocupada
				peticion_memoria_lectura(v_pet_m); -- peticion de lectura a memoria

			when ESPL =>
				interfaces_en_CURSO(v_resp); -- cache ocupada

			when ESB =>
				interfaces_en_CURSO(v_resp); -- cache ocupada
				actualizar_etiqueta(v_s_control); -- actualiza la etiqueta
				actualizar_estado(v_s_control, contenedor_valido);  -- actualiza el estado
				actualizar_dato(v_s_control); -- actualiza el dato
				actu_datos_desde_bus(v_s_control); -- actualiza datos desde bus

			when PMEA =>
				interfaces_en_CURSO(v_resp); -- cache ocupada
				peticion_memoria_escritura(v_pet_m); -- peticion de escritura a memoria

			when ESPEA =>
				interfaces_en_CURSO(v_resp); -- cache ocupada

			when ESCP =>
				interfaces_en_CURSO(v_resp); -- respuesta al procesador hecha (escritura)
			  	actualizar_dato(v_s_control); -- actualiza el dato
			
			when PMEF =>
				interfaces_en_CURSO(v_resp); -- cache ocupada
				peticion_memoria_escritura(v_pet_m); -- peticion de escritura a memoria
			
			when ESPEF =>
				interfaces_en_CURSO(v_resp); -- cache ocupada

			when HECHOE =>
				interfaces_HECHOE(v_resp); -- respuesta al procesador hecha (escritura)

			when others =>
				null;

		end case;
	end if;

	s_control <= v_s_control after retardo_logica_salida;
	resp <= v_resp after retardo_logica_salida;
	pet_m <= v_pet_m after retardo_logica_salida;

end process;

end;
