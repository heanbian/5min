package chat.fivemin.app.data

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.core.content.edit
import java.nio.ByteBuffer
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Device cloud credentials encrypted with Android Keystore AES-256-GCM. Fail-closed (no plaintext). */
class SecureCredentialStore(context: Context) {
    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    var deviceId: String
        get() = read(KEY_DEVICE_ID).orEmpty()
        set(value) = write(KEY_DEVICE_ID, value)

    var deviceSecret: String
        get() = read(KEY_DEVICE_SECRET).orEmpty()
        set(value) = write(KEY_DEVICE_SECRET, value)

    fun setCredentials(id: String, secret: String) {
        val encId = encrypt(id)
        val encSecret = encrypt(secret)
        prefs.edit {
            putString(KEY_DEVICE_ID, encId)
            putString(KEY_DEVICE_SECRET, encSecret)
        }
    }

    fun clear() {
        prefs.edit {
            remove(KEY_DEVICE_ID)
            remove(KEY_DEVICE_SECRET)
        }
    }

    private fun read(key: String): String? {
        val packed = prefs.getString(key, null) ?: return null
        if (!packed.startsWith(ENC_PREFIX)) {
            // Wipe legacy/plaintext values — never return them.
            prefs.edit { remove(key) }
            return null
        }
        return decrypt(packed)
    }

    private fun write(key: String, value: String) {
        prefs.edit { putString(key, encrypt(value)) }
    }

    private fun encrypt(plain: String): String {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
        val iv = cipher.iv
        val body = cipher.doFinal(plain.toByteArray(Charsets.UTF_8))
        val packed = ByteBuffer.allocate(4 + iv.size + body.size)
            .putInt(iv.size)
            .put(iv)
            .put(body)
            .array()
        return ENC_PREFIX + Base64.encodeToString(packed, Base64.NO_WRAP)
    }

    private fun decrypt(packed: String): String? {
        return runCatching {
            val raw = Base64.decode(packed.removePrefix(ENC_PREFIX), Base64.NO_WRAP)
            val buffer = ByteBuffer.wrap(raw)
            val ivSize = buffer.int
            require(ivSize in 1..64) { "invalid iv" }
            val iv = ByteArray(ivSize)
            buffer.get(iv)
            val body = ByteArray(buffer.remaining())
            buffer.get(body)
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(), GCMParameterSpec(GCM_TAG_BITS, iv))
            cipher.doFinal(body).toString(Charsets.UTF_8)
        }.getOrNull()
    }

    private fun getOrCreateKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }

        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return generator.generateKey()
    }

    companion object {
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val KEY_ALIAS = "chat.fivemin.app.secure_credentials"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val GCM_TAG_BITS = 128
        private const val PREFS_NAME = "5min_secure_prefs"
        private const val ENC_PREFIX = "enc:"
        private const val KEY_DEVICE_ID = "device_id"
        private const val KEY_DEVICE_SECRET = "device_secret"
    }
}
