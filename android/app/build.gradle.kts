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
// FIX: solo ciertos plugins antiguos (usage_stats, y device_apps si
// vuelve a usarse) declaran un "compileSdk"/"namespace" desactualizado en
// su propio build.gradle, lo que rompe AAPT con recursos que dependen de
// atributos de plataformas más nuevas (p. ej. android:attr/lStar, API 31+).
//
// IMPORTANTE: este parche se limita EXPLÍCITAMENTE por nombre de
// subproyecto a los plugins rotos conocidos. Aplicarlo a TODOS los
// subproyectos (como hacíamos antes) rompe a plugins bien mantenidos como
// android_intent_plus, porque Gradle ya "congela" su compileSdk correcto
// muy temprano, y forzar un nuevo valor después lanza
// "It is too late to set compileSdk". Al tocar solo los módulos
// realmente problemáticos, evitamos ese efecto colateral.
// -----------------------------------------------------------------------
val brokenLegacyModules = setOf("usage_stats", "device_apps")

subprojects {
    val proj = this
    if (proj.name !in brokenLegacyModules) return@subprojects

    plugins.withId("com.android.library") {
        fun applyGradleCompatFix() {
            val androidExt = proj.extensions.getByType(
                com.android.build.gradle.LibraryExtension::class.java
            )

            // Namespace faltante.
            if (androidExt.namespace == null) {
                val manifestFile = proj.file("src/main/AndroidManifest.xml")
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

            // compileSdk desactualizado -> solo lo subimos si de verdad
            // hace falta (evita tocar módulos que ya estén bien).
            val current = androidExt.compileSdk
            if (current == null || current < 31) {
                androidExt.compileSdk = 35
            }
        }

        if (proj.state.executed) {
            applyGradleCompatFix()
        } else {
            proj.afterEvaluate {
                applyGradleCompatFix()
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
