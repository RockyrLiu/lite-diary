package com.example.lite_diary

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "lite_diary/file_picker"
    private var pendingPickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickFile" -> {
                        pendingPickResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf(
                                "text/markdown", "text/plain",
                                "application/zip", "application/octet-stream", "*/*"
                            ))
                            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, false)
                        }
                        startActivityForResult(intent, 1001)
                    }
                    "saveFile" -> {
                        val sourcePath = call.argument<String>("sourcePath") ?: ""
                        val fileName = call.argument<String>("fileName") ?: "export.zip"
                        Thread {
                            val ok = saveToDownloads(sourcePath, fileName)
                            runOnUiThread { result.success(ok) }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 1001) {
            val result = pendingPickResult ?: return
            pendingPickResult = null
            if (resultCode == RESULT_OK && data?.data != null) {
                val uri = data.data!!
                val fileName = getFileName(uri) ?: "import.md"
                try {
                    val tempFile = File(cacheDir, "import_$fileName")
                    contentResolver.openInputStream(uri)?.use { input ->
                        FileOutputStream(tempFile).use { output -> input.copyTo(output) }
                    }
                    result.success(mapOf("path" to tempFile.absolutePath, "name" to fileName))
                    return
                } catch (_: Exception) {}
            }
            result.success(null)
        }
    }

    private fun saveToDownloads(sourcePath: String, fileName: String): Boolean {
        return try {
            val sourceFile = File(sourcePath)
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, "application/zip")
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }
            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            uri?.let {
                contentResolver.openOutputStream(it)?.use { output ->
                    sourceFile.inputStream().use { input -> input.copyTo(output) }
                }
            }
            uri != null
        } catch (_: Exception) {
            false
        }
    }

    private fun getFileName(uri: Uri): String? {
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (idx >= 0 && cursor.moveToFirst()) return cursor.getString(idx)
        }
        return null
    }
}
