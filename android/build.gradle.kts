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
// FIX: algunos plugins antiguos (como device_apps) no declaran "namespace"
// en su build.gradle, algo que AGP 8+ exige obligatoriamente. Este bloque
// lo detecta leyendo el atributo "package" del AndroidManifest.xml de
// cada subproyecto de tipo librería y se lo asigna automáticamente si
// falta, sin tocar el código del plugin en sí.
// -----------------------------------------------------------------------
subprojects {
    afterEvaluate {
        if (project.plugins.hasPlugin("com.android.library")) {
            val androidExt = project.extensions.findByType(
                com.android.build.gradle.LibraryExtension::class.java
            )
            if (androidExt != null && androidExt.namespace == null) {
                val manifestFile = project.file("src/main/AndroidManifest.xml")
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
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
