allprojects {
    repositories {
        google()
        mavenCentral()

        // 👇 REQUIRED FOR FFMPEG KIT
        maven(url = "https://raw.githubusercontent.com/arthenica/ffmpeg-kit/main/prebuilt/android")
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
