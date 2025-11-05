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

derechos_acceso <= '1' when (s_estado.AF and s_estado.EST) = '1' else '0';

-- registro de estado
reg_estado: process (reloj, pcero)
variable v_estado: tipoestado;
begin
	if pcero = '1' then
		v_estado := DES0;
	elsif rising_edge(reloj) then
		v_estado := prxestado;										
	end if;
	estado <= v_estado after retardo_estado;
end process;    
   
-- logica de proximo estado
prx_esta: process(estado, pet, derechos_acceso, resp_m, pcero)
variable v_prxestado: tipoestado;
begin
	v_prxestado := estado;
	if pcero /= '1' then
		case estado is
			when DES0 =>
				-- Si no hay peticion, se mantiene en DES0
				if not hay_peticion_procesador (pet) then
					v_prxestado := DES0;
				-- Si hay peticion ini
				elsif hay_peticion_ini_procesador(pet) then
					v_prxestado := INI;
				else
					-- Si tengo una peticion de lectura (será fallo)
					if pet.esc = '0' then
						v_prxestado := ESPL;
					else -- Si tengo una peticion de escritura (será fallo)
						v_prxestado := ESPEF;
					end if;
				end if;

			when INI =>
				v_prxestado := ESCINI;

			when ESCINI =>
				v_prxestado := DES;

			when DES =>
				-- Si tengo una peticion de lectura
				if hay_peticion_procesador(pet) then
					if es_acierto_lectura (pet, derechos_acceso) then -- hay acierto
						v_prxestado := DES;
					elsif es_fallo_lectura (pet, derechos_acceso) then -- hay fallo
						v_prxestado := ESPL;
					elsif es_acierto_escritura (pet, derechos_acceso) then -- hay acierto
						v_prxestado := ESPEA;
					elsif es_fallo_escritura (pet, derechos_acceso) then -- hay fallo
						v_prxestado := ESPEF;
					end if;
				else
					v_prxestado := DES;
				end if;

			when ESPL =>
				if hay_respuesta_memoria (resp_m) then
					v_prxestado := ESB;
				else
					v_prxestado := ESPL;
				end if;

			when ESB =>
				v_prxestado := DES;

			when ESPEA =>
				if hay_respuesta_memoria (resp_m) then
					v_prxestado := ESCP;
				else
					v_prxestado := ESPEA;
				end if;

			when ESCP =>
				v_prxestado := DES;

			when ESPEF =>
				if hay_respuesta_memoria (resp_m) then
					v_prxestado := DES;
				else
					v_prxestado := ESPEF;
				end if;

			when others =>
				null;

		end case;
	else 
		v_prxestado := DES0;
	end if;

	prxestado <= v_prxestado after retardo_logica_prx_estado;
end process;
   
-- logica de salida
logi_sal: process(estado, pet, derechos_acceso, resp_m, pcero)
variable v_s_control: tp_contro_cam_cntl;
variable v_resp: tp_contro_s;
variable v_pet_m: tp_cntl_memoria_s;

begin
-- valores por defecto
	por_defecto(v_s_control, v_pet_m, v_resp);

	if pcero /= '1' then
		case estado is
			when DES0 =>
				if hay_peticion_procesador(pet) then
					if hay_peticion_ini_procesador (pet) then
						no_acceder_campos_cache(v_s_control);
					else
						if es_fallo_lectura(pet, derechos_acceso) then
							peticion_memoria_lectura(v_pet_m);
							interfaces_en_CURSO(v_resp); -- cache ocupada
						elsif es_fallo_escritura(pet, derechos_acceso) then
							peticion_memoria_escritura(v_pet_m);
							interfaces_en_CURSO(v_resp); -- cache ocupada
						end if;
					end if;
				else 
					interfaces_DES(v_resp);
				end if;

			when INI =>
				interfaces_en_CURSO(v_resp); -- cache ocupada

			when ESCINI =>
				interfaces_HECHOE_listo(v_resp); -- cache ocupada
				actualizar_etiqueta(v_s_control); -- actualiza la etiqueta
				actualizar_estado(v_s_control, contenedor_valido);  -- actualiza el estado
				actualizar_dato (v_s_control); -- actualiza el dato

			when DES =>
				if hay_peticion_procesador(pet) then
					if es_acierto_lectura(pet, derechos_acceso) then
						interfaces_HECHOL_listo(v_resp);
					elsif es_fallo_lectura(pet, derechos_acceso) then
						peticion_memoria_lectura(v_pet_m);
						interfaces_en_CURSO(v_resp); -- cache ocupada
					elsif es_acierto_escritura(pet, derechos_acceso) then
						peticion_memoria_escritura(v_pet_m);
						interfaces_en_CURSO(v_resp);
					elsif es_fallo_escritura(pet, derechos_acceso) then
						peticion_memoria_escritura(v_pet_m);
						interfaces_en_CURSO(v_resp);
					end if;
				else 
					interfaces_DES(v_resp); -- pc_listo
				end if;
			
			when ESPL =>
				interfaces_en_CURSO(v_resp); -- cache ocupada
				if hay_respuesta_memoria(resp_m) then
					actualizar_etiqueta(v_s_control); -- actualiza la etiqueta
					actualizar_estado(v_s_control, contenedor_valido);  -- actualiza el estado
					actualizar_dato(v_s_control); -- actualiza el dato
					actu_datos_desde_bus(v_s_control); -- actualiza datos desde bus
				else
					no_acceder_campos_cache(v_s_control);
				end if;

			when ESB =>
				interfaces_HECHOL_listo(v_resp);
				sumi_dato_proc_desde_bus(v_s_control);
				
			when ESPEA =>
				if hay_respuesta_memoria(resp_m) then
					interfaces_en_CURSO (v_resp);
					actualizar_dato (v_s_control);
				else
					no_acceder_campos_cache (v_s_control);
				end if;

			when ESCP =>
				interfaces_HECHOE_listo (v_resp); -- respuesta al procesador hecha (escritura)
			
			when ESPEF =>
				if (hay_respuesta_memoria(resp_m)) then
					interfaces_HECHOE_listo(v_resp);
				else 
					interfaces_en_CURSO(v_resp);
					no_acceder_campos_cache(v_s_control);
				end if;

			when others =>
				null;

		end case;
	end if;


s_control <= v_s_control after retardo_logica_salida;
resp <= v_resp after retardo_logica_salida;
pet_m <= v_pet_m after retardo_logica_salida;

end process;

	
end;
