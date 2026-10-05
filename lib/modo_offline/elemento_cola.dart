class ElementoCola {
  final String id;
  final String userId;
  final String metodo; // POST, PUT, PATCH, DELETE
  final String endpoint;
  final Map<String, dynamic>? cuerpo;
  final String tipoAccion; // CREAR_CITA, ACTUALIZAR_PERFIL, etc.
  final String descripcionHumana;
  final DateTime fechaCreacion;
  int reintentos;
  String estado; // PENDIENTE, SINCRONIZANDO, ERROR_CONFLICTO, COMPLETADO
  String? mensajeError;
  final Map<String, dynamic>? metadata;

  ElementoCola({
    required this.id,
    required this.userId,
    required this.metodo,
    required this.endpoint,
    this.cuerpo,
    required this.tipoAccion,
    required this.descripcionHumana,
    required this.fechaCreacion,
    this.reintentos = 0,
    this.estado = 'PENDIENTE',
    this.mensajeError,
    this.metadata,
  });

  bool get esCita => tipoAccion == 'CREAR_CITA';
  bool get esFichaMedica => tipoAccion == 'ACTUALIZAR_FICHA_MEDICA';
  bool get tieneErrorConflicto => estado == 'ERROR_CONFLICTO';
  bool get estaPendiente => estado == 'PENDIENTE';

  factory ElementoCola.fromJson(Map<String, dynamic> json) {
    return ElementoCola(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      metodo: json['metodo'] as String,
      endpoint: json['endpoint'] as String,
      cuerpo: json['cuerpo'] as Map<String, dynamic>?,
      tipoAccion: json['tipo_accion'] as String,
      descripcionHumana: json['descripcion_humana'] as String? ?? 'Acción offline',
      fechaCreacion: DateTime.parse(json['fecha_creacion'] as String),
      reintentos: json['reintentos'] as int? ?? 0,
      estado: json['estado'] as String? ?? 'PENDIENTE',
      mensajeError: json['mensaje_error'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'metodo': metodo,
      'endpoint': endpoint,
      'cuerpo': cuerpo,
      'tipo_accion': tipoAccion,
      'descripcion_humana': descripcionHumana,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'reintentos': reintentos,
      'estado': estado,
      'mensaje_error': mensajeError,
      'metadata': metadata,
    };
  }
}
