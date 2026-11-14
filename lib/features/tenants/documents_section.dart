import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/documents.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

const _red = Color(0xFFDC2626);

/// "Documents submitted" checkbox + document thumbnails + Add Document.
/// [onChanged] is called with the new list and checkbox value; the caller
/// saves them (immediately on the tenant page, on Save in the add form).
class DocumentsSection extends ConsumerWidget {
  const DocumentsSection({
    super.key,
    required this.tenantId,
    required this.documents,
    required this.submitted,
    required this.onChanged,
  });

  final String tenantId;
  final List<TenantDocument> documents;
  final bool submitted;
  final void Function(List<TenantDocument> docs, bool submitted) onChanged;

  Future<void> _add(BuildContext context, String docsDir) async {
    final picked = await showModalBottomSheet<_Picked>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _AddDocumentSheet(),
    );
    if (picked == null || picked.paths.isEmpty) return;
    try {
      final added = <TenantDocument>[];
      for (final (i, path) in picked.paths.indexed) {
        added.add(await storeDocument(
          docsDir: docsDir,
          tenantId: tenantId,
          sourcePath: path,
          label: picked.paths.length > 1
              ? '${picked.label} (${i + 1})'
              : picked.label,
        ));
      }
      // Adding a document ticks "submitted" automatically.
      onChanged([...documents, ...added], true);
      if (context.mounted) {
        showSaved(
            context,
            added.length == 1
                ? '${added.first.label} added'
                : '${added.length} documents added');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save the document: $e')));
      }
    }
  }

  Future<void> _open(
      BuildContext context, String docsDir, TenantDocument d) async {
    final delete = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) =>
          DocumentViewer(document: d, file: docFilePath(docsDir, d)),
    ));
    if (delete == true) {
      await deleteDocumentFiles(docsDir, [d]);
      onChanged(documents.where((x) => x.id != d.id).toList(), submitted);
      if (context.mounted) showSaved(context, '${d.label} deleted');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsDir = ref.watch(docsDirProvider).value;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CheckboxListTile(
              value: submitted,
              onChanged: (v) => onChanged(documents, v ?? false),
              secondary: Icon(
                  submitted
                      ? Icons.verified_user_rounded
                      : Icons.gpp_maybe_rounded,
                  color: submitted ? AppColors.success : _red),
              title: const Text('Documents submitted'),
              subtitle: Text(
                submitted
                    ? 'ID proof collected'
                    : 'Document proof not submitted',
                style: TextStyle(color: submitted ? null : _red),
              ),
            ),
            if (documents.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final d in documents)
                    _Thumb(
                      document: d,
                      file: docsDir == null ? null : docFilePath(docsDir, d),
                      onTap: docsDir == null
                          ? null
                          : () => _open(context, docsDir, d),
                    ),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: OutlinedButton.icon(
                onPressed:
                    docsDir == null ? null : () => _add(context, docsDir),
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: Text(documents.isEmpty
                    ? 'Add Document +'
                    : 'Add Document + (${documents.length} added)'),
              ),
            ),
            if (documents.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                    'Optional · take a photo or upload Aadhaar, PAN, ID card, agreement…',
                    style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.document, required this.file, this.onTap});
  final TenantDocument document;
  final String? file;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget placeholder(IconData icon) => Container(
          color: scheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(icon, size: 36, color: scheme.onSurfaceVariant),
        );
    return SizedBox(
      width: 96,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 96,
              height: 96,
              child: document.isPdf || file == null
                  ? placeholder(document.isPdf
                      ? Icons.picture_as_pdf_rounded
                      : Icons.image_outlined)
                  : Image.file(File(file!),
                      fit: BoxFit.cover,
                      cacheWidth: 288,
                      errorBuilder: (_, __, ___) =>
                          placeholder(Icons.broken_image_outlined)),
            ),
          ),
          const SizedBox(height: 4),
          Text(document.label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
  }
}

class _Picked {
  const _Picked(this.label, this.paths);
  final String label;
  final List<String> paths;
}

/// Choose document type, then camera / gallery / PDF.
class _AddDocumentSheet extends StatefulWidget {
  const _AddDocumentSheet();

  @override
  State<_AddDocumentSheet> createState() => _AddDocumentSheetState();
}

class _AddDocumentSheetState extends State<_AddDocumentSheet> {
  String _type = documentTypes.first;
  final _custom = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  String get _label {
    if (_type != 'Other') return _type;
    final t = _custom.text.trim();
    return t.isEmpty ? 'Document' : t;
  }

  Future<void> _pick(Future<List<String>> Function() picker) async {
    setState(() => _busy = true);
    try {
      final paths = await picker();
      if (!mounted) return;
      if (paths.isEmpty) {
        setState(() => _busy = false);
        return;
      }
      Navigator.pop(context, _Picked(_label, paths));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not open: $e')));
    }
  }

  Future<List<String>> _camera() async {
    final x = await ImagePicker().pickImage(
        source: ImageSource.camera, imageQuality: 80, maxWidth: 2000);
    return x == null ? [] : [x.path];
  }

  Future<List<String>> _gallery() async {
    final xs =
        await ImagePicker().pickMultiImage(imageQuality: 80, maxWidth: 2000);
    return xs.map((x) => x.path).toList();
  }

  Future<List<String>> _pdf() async {
    final x = await openFile(acceptedTypeGroups: const [
      XTypeGroup(
          label: 'PDF', extensions: ['pdf'], mimeTypes: ['application/pdf']),
    ]);
    return x == null ? [] : [x.path];
  }

  @override
  Widget build(BuildContext context) {
    Widget option(IconData icon, Color color, String title, String sub,
            Future<List<String>> Function() picker) =>
        ListTile(
          enabled: !_busy,
          leading: IconBadge(icon: icon, color: color),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(sub),
          onTap: () => _pick(picker),
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add Document',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const FormLabel('Document type'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in documentTypes)
                  ChoiceChip(
                    label: Text(t),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ]),
              if (_type == 'Other') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _custom,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Document name'),
                ),
              ],
              const FormLabel('Add from'),
              Card(
                child: Column(children: [
                  option(Icons.photo_camera_rounded, AppColors.seed,
                      'Take photo', 'Open camera', _camera),
                  const Divider(height: 1),
                  option(
                      Icons.photo_library_rounded,
                      AppColors.success,
                      'Choose from gallery',
                      'Select one or more photos',
                      _gallery),
                  const Divider(height: 1),
                  option(Icons.picture_as_pdf_rounded, _red, 'Upload PDF',
                      'Pick a PDF file from the phone', _pdf),
                ]),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen view of one document. Pops `true` when the user deletes it.
class DocumentViewer extends StatelessWidget {
  const DocumentViewer({super.key, required this.document, required this.file});
  final TenantDocument document;
  final String file;

  @override
  Widget build(BuildContext context) {
    final exists = File(file).existsSync();
    return Scaffold(
      backgroundColor: document.isPdf ? null : Colors.black,
      appBar: AppBar(
        title: Text(document.label),
        actions: [
          if (exists)
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.share_rounded),
              onPressed: () => SharePlus.instance.share(ShareParams(
                files: [XFile(file)],
                subject: document.label,
              )),
            ),
          IconButton(
            tooltip: 'Delete document',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final ok = await confirmDialog(context,
                  title: 'Delete ${document.label}?',
                  message: 'The file will be removed from this phone.');
              if (ok && context.mounted) Navigator.pop(context, true);
            },
          ),
        ],
      ),
      body: !exists
          ? const Center(
              child: EmptyState(
                icon: Icons.broken_image_outlined,
                title: 'File not found',
                message: 'The file may have been removed, or this data was '
                    'imported from another phone.',
              ),
            )
          : document.isPdf
              ? PdfPreview(
                  build: (_) => File(file).readAsBytes(),
                  useActions: false,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                )
              : InteractiveViewer(
                  maxScale: 6,
                  child: Center(
                    child: Image.file(File(file),
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 64)),
                  ),
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Added ${fmtDate(document.addedAt)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: document.isPdf ? null : Colors.white70, fontSize: 12)),
        ),
      ),
    );
  }
}
