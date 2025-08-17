public extension XcodeProductType {
    var isTestType: Bool {
        switch self {
        case .unitTestBundle, .uiTestBundle, .ocUnitTestBundle:
            true
        default:
            false
        }
    }

    var isLibraryType: Bool {
        switch self {
        case .framework, .staticLibrary, .dynamicLibrary:
            true
        default:
            false
        }
    }

    var isApplicationType: Bool {
        switch self {
        case .application, .watchApp:
            true
        default:
            false
        }
    }

    var isRunnableType: Bool {
        switch self {
        case .application, .watchApp, .commandLineTool:
            true
        default:
            false
        }
    }
}
