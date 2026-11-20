import 'dart:io';

import 'package:chiron/data/program_catalog.dart';

/// Parses the program YAML files in [dir] directly from disk.
ProgramCatalog loadCatalogFromDir(String dir) {
  final files =
      Directory(dir)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.yaml'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return ProgramCatalog.parse({
    for (final f in files) f.path: f.readAsStringSync(),
  });
}

ProgramCatalog get exampleCatalog =>
    loadCatalogFromDir('assets/programs/example');
