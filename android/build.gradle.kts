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
// FIX: varios plugins antiguos (device_apps, usage_stats, etc.) declaran
// ellos mismos un "compileSdkVersion" desactualizado DENTRO de su propio
// build.gradle, en una línea que se ejecuta DESPUÉS de que nuestro
// "plugins.withId" se dispara. Eso significa que si forzamos compileSdk
// justo ahí, el propio plugin lo vuelve a pisar un instante después.
//
// La solución es aplicar el fix en "afterEvaluate" (cuando el script
// completo del subproyecto, incluido su bloque android{}, ya terminó de
// ejecutarse) para que nuestro valor sea el que quede al final. Pero como
// "evaluationDependsOn(:app)" de arriba puede hacer que algunos
// subproyectos YA estén evaluados para cuando llegamos aquí (lo cual
// rompía afterEvaluate con "already evaluated"), verificamos el estado
// primero y aplicamos el fix inmediatamente en ese caso.
// -----------------------------------------------------------------------
subprojects {
    val proj = this

    plugins.withId("com.android.library") {
        fun applyGradleCompatFix() {
            val androidExt = proj.extensions.getByType(
                com.android.build.gradle.LibraryExtension::class.java
            )

            // Fix 1: namespace faltante.
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

            // Fix 2: forzamos compileSdk moderno DESPUÉS de que el plugin
            // haya terminado de configurar su propio bloque android{}.
            androidExt.compileSdk = 35
        }

        // Si el subproyecto ya terminó de evaluarse (puede pasar por el
        // evaluationDependsOn(":app") de arriba), aplicamos el fix ya
        // mismo. Si no, esperamos a que termine con afterEvaluate.
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
