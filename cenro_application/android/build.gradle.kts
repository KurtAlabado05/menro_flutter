buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Required for Firebase/Google services
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

/**
 * FIX FOR PATHING/SPACES
 * We changed "../../build" to "../build" so it stays relative 
 * to the Android folder, putting it inside your project root.
 */
val rootBuildDir = rootProject.projectDir.resolve("../build")
rootProject.layout.buildDirectory.set(rootBuildDir)

subprojects {
    val subprojectBuildDir = rootBuildDir.resolve(project.name)
    project.layout.buildDirectory.set(subprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}