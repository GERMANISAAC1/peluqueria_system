allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// -----------------------------------------------------------------------
// FIX: varios plugins antiguos (device_apps, usage_stats, etc.) no
// declaran "namespace" y/o usan un "compileSdk" desactualizado en su
// propio build.gradle. Esto hace que AAPT falle al enlazar recursos que
// dependen de atributos de plataformas más nuevas (p. ej.
// android:attr/lStar, de API 31+) que otras dependencias sí traen.
// Corregimos ambas cosas para TODOS los subproyectos de tipo librería,
// sin modificar el código de ningún plugin.
// -----------------------------------------------------------------------
subprojects {
    plugins.withId("com.android.library") {
        val androidExt = extensions.getByType(
            com.android.build.gradle.LibraryExtension::class.java
        )

        // Fix 1: namespace faltante.
        if (androidExt.namespace == null) {
            val manifestFile = file("src/main/AndroidManifest.xml")
            if (manifestFile.exists()) {
                val doc = javax.xml.parsers.DocumentBuilderFactory
                    .newInstance()
                    .newDocumentBuilder()
                    .parse(manifestFile)
                val packageName = doc.documentElement.getAttribute("package")
                if (packageName.isNotEmpty()) {
                    androidExt.namespace = packageName
                }
            }
        }

        // Fix 2: compileSdk desactualizado -> forzamos uno moderno para
        // TODOS los subproyectos, sin excepción (esto es lo que faltaba:
        // el fix anterior solo cubría casos puntuales si no se aplicaba
        // globalmente a cada subproyecto de tipo librería detectado).
        androidExt.compileSdk = 35
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
