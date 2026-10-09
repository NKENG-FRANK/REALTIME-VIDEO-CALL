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

fun updateSubprojectCompileSdk(subproject: Project) {
    val androidExt = subproject.extensions.findByName("android") ?: return
    val candidates = listOf("compileSdkVersion", "setCompileSdkVersion", "setCompileSdk")
    for (candidate in candidates) {
        for (m in androidExt.javaClass.methods) {
            if (m.name == candidate && m.parameterTypes.size == 1) {
                val paramType = m.parameterTypes[0]
                if (paramType == Int::class.javaPrimitiveType || paramType == java.lang.Integer::class.java) {
                    try {
                        m.invoke(androidExt, 34)
                        return
                    } catch (_: Exception) {}
                }
            }
        }
    }
}

subprojects {
    if (project.name != "app") {
        if (project.state.executed) {
            updateSubprojectCompileSdk(project)
        } else {
            project.afterEvaluate {
                updateSubprojectCompileSdk(project)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
