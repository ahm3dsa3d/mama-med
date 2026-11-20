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
    // Only redirect the build dir for :app.
    // Flutter plugin subprojects (e.g. android_intent_plus) live in the Pub
    // cache on a different drive (C:\). Redirecting their build dir to D:\
    // causes Gradle to fail with "this and base files have different roots"
    // because it cannot relativize paths across Windows drive boundaries.
    if (project.name == "app") {
        val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
        project.layout.buildDirectory.value(newSubprojectBuildDir)
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
