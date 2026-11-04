import 'dart:io';
import 'package:llamadart/llamadart.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) { stderr.writeln('Pass a verified local GGUF model path.'); exitCode = 2; return; }
  // A local path is used deliberately: this execution must not download a model.
  final engine = await LlamaEngine.load(LlamaModel(ModelSource.path(args.first)),
    params: const ModelParams(contextSize: 2048, gpuLayers: 0, device: ComputeDevice.cpu, numberOfThreads: 4, batchSize: 128));
  try {
    final reply = await engine.create(const [
      LlamaChatMessage.fromText(role: LlamaChatRole.system, text: 'Responde solo en español y brevemente.'),
      LlamaChatMessage.fromText(role: LlamaChatRole.user, text: 'Saluda con una frase corta. ¿Cómo te llamas si tu nombre es Carlitos?'),
    ], params: const GenerationParams(maxTokens: 48, temp: 0.2)).text();
    if (reply.trim().isEmpty) throw StateError('The model generated no text.');
    stdout.writeln('LOCAL_GENERATION_OK: $reply');
  } finally { await engine.dispose(); }
}
