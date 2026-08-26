part of '../system_prompt.dart';

/// LAS `instructions` DE CADA SERVIDOR MCP PROPIO DE KEEL.
///
/// Qué dicen: una o dos frases por servidor, que el cliente MCP le muestra
/// al modelo junto con la lista de tools. No describen una tool —eso es el
/// `description` de cada una— sino QUÉ ES ese servidor y cuál es la regla
/// que no se deduce del esquema: que los tableros los arma el agente pero
/// los dispara el usuario, que una tarea del roadmap hay que tomarla antes
/// de trabajarla, que cerrar un requerimiento es de quien lo abrió.
///
/// Por qué están acá: son texto de conducta, igual que el resto del corpus.
/// Estaban embebidas en el constructor de cada servidor, que es el último
/// lugar donde alguien las busca cuando quiere revisar qué se le está
/// diciendo al modelo.
///
/// Quién las usa: el constructor de cada `*_mcp_server*.dart`, en
/// `Implementation(instructions: …)`.
///
/// Lo que NO se movió: las descripciones de las tools. Esas son parte del
/// esquema que valida el servidor y se leen junto al `inputSchema`.
const kKeelAiMcpInstructions =
    'Tools to inspect, create, update and delete Keel AI objects, '
    'including complete workflow contracts.';

const kBoardsMcpInstructions =
    'Los tableros de prueba de este proyecto: pantallitas para que '
    'el usuario dispare algo contra su propia app. Vos los ARMÁS; '
    'dispararlos es de él, y por eso no hay tool para correrlos.';

const kSessionPlanMcpInstructions =
    'El plan de trabajo de la sesión en la que estás.';

const kRoadmapMcpInstructions =
    'El roadmap de este proyecto. Antes de trabajar en una tarea, '
    'tomala: si otro la tiene, pasá a la siguiente.';

const kRequirementsMcpInstructions =
    'Lo que este proyecto le pide a otros y lo que otros le piden a '
    'él. Cerrar un requerimiento es de quien lo abrió: del otro lado '
    'se PIDE el cierre, con justificación.';

const kUserToolsMcpInstructions =
    'Tools deterministas registradas por el usuario, asignadas a '
    'este agente. Cada una ejecuta un script real y devuelve su '
    'salida.';
