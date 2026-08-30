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

// NOTA: el parche de "namespace"/"compileSdk" para plugins desactualizados
// que tuvimos aquí (para device_apps y usage_stats) ya NO es necesario:
// ambos paquetes fueron reemplazados por código nativo propio en
// MainActivity.kt / AppBlockAccessibilityService.kt. Si en el futuro
// agregas otro plugin de terceros con el mismo problema
// ("Namespace not specified" o "resource android:attr/lStar not found"),
// la solución más segura -aprendida a las malas en este proyecto- es
// reemplazar ese plugin por un MethodChannel propio en vez de forzar su
// configuración de Gradle: forzar compileSdk en subprojects rompe a otros
// plugins bien mantenidos que ya "congelan" su propio compileSdk temprano.

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
