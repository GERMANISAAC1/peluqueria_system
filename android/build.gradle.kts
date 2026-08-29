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
// en su build.gradle, algo que AGP 8+ exige. Usamos plugins.withId en vez
// de afterEvaluate para evitar conflicto con evaluationDependsOn de arriba
// (afterEvaluate revienta con "project already evaluated" en ese escenario).
// -----------------------------------------------------------------------
subprojects {
    plugins.withId("com.android.library") {
        val androidExt = extensions.getByType(
            com.android.build.gradle.LibraryExtension::class.java
        )
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
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
