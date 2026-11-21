package chat.fivemin.app

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * Non-exported entry for launcher shortcuts. Other apps cannot start this component.
 */
class ShortcutActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val scene = intent.getStringExtra(EXTRA_SCENE_ID).orEmpty()
        if (scene.isNotBlank()) {
            ShortcutPending.offer(scene)
        }
        startActivity(
            Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            },
        )
        finish()
    }

    companion object {
        const val EXTRA_SCENE_ID = "scene_id"
    }
}
