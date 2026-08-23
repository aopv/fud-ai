pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}
plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        val flutterAarRepository = settingsDir.parentFile.resolve(
            "flutter_shared/build/android-repository/host/outputs/repo"
        )
        maven(flutterAarRepository) {
            content { includeGroup("com.apoorvdarshan.fud_ai_shared") }
        }
        val flutterStorage = System.getenv("FLUTTER_STORAGE_BASE_URL")
            ?: "https://storage.googleapis.com"
        maven("$flutterStorage/download.flutter.io") {
            content { includeGroup("io.flutter") }
        }
        google()
        mavenCentral()
    }
}

rootProject.name = "Fud AI"
include(":app")
