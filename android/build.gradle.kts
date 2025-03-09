allprojects {
    repositories {
        google()
        mavenCentral()
    }

    subprojects {
        afterEvaluate { 
            if (project.hasProperty("android")) {
                val androidExt = project.extensions.findByName("android")
                if (androidExt != null && androidExt is com.android.build.gradle.BaseExtension) {
                    if (androidExt.namespace == null) {
                        androidExt.namespace = project.group.toString()
                    }
                }
            }
        }
    }
}

val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
