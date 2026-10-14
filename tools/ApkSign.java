// Signs an APK with APK Signature Scheme v2 using the apksig library
// (com.android.tools.build:apksig from Maven Central), so no Android SDK is needed.
// Godot 4.7 APKs require Android 7.0+ (minSdk 24), where v2 alone is enough;
// the Maven Central apksig is too old to produce v1 signatures on modern JDKs.
//
// Usage:
//   javac -cp apksig.jar -d out tools/ApkSign.java
//   java --add-exports java.base/sun.security.x509=ALL-UNNAMED -cp apksig.jar:out ApkSign <keystore.p12> <storepass> <alias> <in.apk> <out.apk>
import com.android.apksig.ApkSigner;

import java.io.File;
import java.io.FileInputStream;
import java.security.KeyStore;
import java.security.PrivateKey;
import java.security.cert.Certificate;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class ApkSign {
    public static void main(String[] args) throws Exception {
        if (args.length != 5) {
            System.err.println("usage: ApkSign <keystore> <storepass> <alias> <in.apk> <out.apk>");
            System.exit(2);
        }
        char[] pass = args[1].toCharArray();
        KeyStore ks = KeyStore.getInstance("PKCS12");
        try (FileInputStream in = new FileInputStream(args[0])) {
            ks.load(in, pass);
        }
        PrivateKey key = (PrivateKey) ks.getKey(args[2], pass);
        List<X509Certificate> certs = new ArrayList<>();
        for (Certificate c : ks.getCertificateChain(args[2])) {
            certs.add((X509Certificate) c);
        }
        ApkSigner.SignerConfig signer = new ApkSigner.SignerConfig.Builder("NEONPRIM", key, certs).build();
        new ApkSigner.Builder(Collections.singletonList(signer))
                .setInputApk(new File(args[3]))
                .setOutputApk(new File(args[4]))
                .setV1SigningEnabled(false)
                .setV2SigningEnabled(true)
                .build()
                .sign();
        System.out.println("Signed: " + args[4]);
    }
}
