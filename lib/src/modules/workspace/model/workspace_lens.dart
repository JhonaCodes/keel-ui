/// Qué muestra el área central, y nada más que eso.
///
/// Existe porque «qué estoy mirando» estaba deducido de tres estados a la
/// vez —el proyecto seleccionado, si tenía sesión activa, y un `_focus` que
/// vivía adentro de la pantalla— y cada uno se podía mover sin los otros. El
/// síntoma era el sidebar marcando una sesión mientras el centro seguía en
/// un tablero.
enum WorkspaceLens {
  /// Un chat 1:1 con un agente suelto.
  agent,

  /// El hilo de un requerimiento.
  requirement,

  /// Cómo va el proyecto.
  projectState,

  /// Los tableros del proyecto, en lista.
  boards,

  /// Un tablero, andando.
  board,

  /// La sesión abierta del proyecto.
  session,
}

/// El área central, en un dato.
class WorkspaceState {
  const WorkspaceState({this.lens = WorkspaceLens.agent, this.boardId});

  final WorkspaceLens lens;

  /// Qué tablero, cuando [lens] es [WorkspaceLens.board]. En cualquier otro
  /// lente es null: un id que sobrevive al lente es el próximo desfasaje.
  final String? boardId;

  /// Si lo que se ve pertenece al proyecto seleccionado. Lo usa el sidebar
  /// para saber cuál de sus secciones va marcada.
  bool get isProjectScoped => switch (lens) {
    WorkspaceLens.projectState ||
    WorkspaceLens.boards ||
    WorkspaceLens.board ||
    WorkspaceLens.session => true,
    WorkspaceLens.agent || WorkspaceLens.requirement => false,
  };

  /// El lente que se puede dibujar de verdad.
  ///
  /// Un tablero borrado deja un id apuntando a nada. En vez de pedirle a
  /// quien borra que se acuerde de avisarle a la navegación —que es la clase
  /// de acuerdo que se rompe la tercera vez—, la vista pregunta antes de
  /// dibujar y cae en la lista.
  WorkspaceLens resolved({required bool boardExists}) =>
      lens == WorkspaceLens.board && !boardExists ? WorkspaceLens.boards : lens;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceState && other.lens == lens && other.boardId == boardId;

  @override
  int get hashCode => Object.hash(lens, boardId);
}
