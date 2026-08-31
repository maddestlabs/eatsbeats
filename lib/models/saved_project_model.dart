class SavedProjectItem {
  final String id;
  final String name;
  final String fileName;
  final String? filePath;
  final int fileSizeBytes;
  final DateTime lastModified;
  final bool isWebStorage;

  SavedProjectItem({
    required this.id,
    required this.name,
    required this.fileName,
    this.filePath,
    required this.fileSizeBytes,
    required this.lastModified,
    this.isWebStorage = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'fileName': fileName,
        'filePath': filePath,
        'fileSizeBytes': fileSizeBytes,
        'lastModified': lastModified.toIso8601String(),
        'isWebStorage': isWebStorage,
      };

  factory SavedProjectItem.fromJson(Map<String, dynamic> json) => SavedProjectItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Untitled Project',
        fileName: json['fileName'] as String? ?? 'project.eats.lua',
        filePath: json['filePath'] as String?,
        fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt() ?? 0,
        lastModified: json['lastModified'] != null
            ? DateTime.tryParse(json['lastModified'] as String) ?? DateTime.now()
            : DateTime.now(),
        isWebStorage: json['isWebStorage'] as bool? ?? false,
      );
}
