package kz.azhar.cloudmount

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import java.io.BufferedReader
import java.io.InputStreamReader

/**
 * Minimal skeleton: no Storage Access Framework, no MANAGE_EXTERNAL_STORAGE —
 * every action here is a plain `su -c "<module script>"` call, since all the
 * real mounting/unmounting logic already lives in the Magisk module's shell
 * scripts. This activity is just a convenient, deterministic on/off switch
 * (see project notes on why an app button beats an inotify auto-mount hook).
 */
class MainActivity : AppCompatActivity() {

    private val moduleDir = "/data/adb/modules/rclone_magisk_cl"
    private lateinit var logText: TextView
    private lateinit var statusText: TextView
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        logText = findViewById(R.id.logText)
        statusText = findViewById(R.id.statusText)

        findViewById<Button>(R.id.btnMountAll).setOnClickListener {
            runRootScript("$moduleDir/scripts/mount-all.sh", "Подключаю все диски…")
        }
        findViewById<Button>(R.id.btnUnmountAll).setOnClickListener {
            runRootScript("$moduleDir/scripts/unmount-all.sh", "Отключаю все диски…")
        }
    }

    private fun runRootScript(scriptPath: String, statusMessage: String) {
        statusText.text = statusMessage
        logText.text = ""

        Thread {
            try {
                val process = ProcessBuilder("su", "-c", "sh $scriptPath")
                    .redirectErrorStream(true)
                    .start()

                val reader = BufferedReader(InputStreamReader(process.inputStream))
                val output = StringBuilder()
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    output.append(line).append('\n')
                    val snapshot = output.toString()
                    mainHandler.post { logText.text = snapshot }
                }
                process.waitFor()

                mainHandler.post {
                    statusText.text = getString(R.string.app_name)
                }
            } catch (e: Exception) {
                mainHandler.post {
                    logText.text = "Ошибка запуска root-команды: ${e.message}\n" +
                        "Проверь, что устройство рутировано и приложению выдан root-доступ."
                }
            }
        }.start()
    }
}
