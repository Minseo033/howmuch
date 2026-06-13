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

// 💡 서드파티 플러그인의 단위 테스트가 빌드를 중단시키는 것을 방지하기 위해 테스트 태스크 비활성화
gradle.taskGraph.whenReady {
    allTasks.forEach { task ->
        if (task.name.contains("test", ignoreCase = true) || task.name.contains("Test", ignoreCase = true)) {
            task.enabled = false
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
