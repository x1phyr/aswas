import Testing
@testable import AswasFinderPoCCore

struct FinderDictionaryInspectorTests {
    @Test
    func detectsWindowCapabilitiesWithoutInventingTabs() {
        let source = """
        <command name="make"/>
        <command name="close"/>
        <element type="Finder window"/>
        <property name="target"/>
        <property name="bounds"/>
        <property name="current view"/>
        """

        let capabilities = FinderDictionaryInspector.inspect(source)

        #expect(capabilities.listWindows)
        #expect(capabilities.readTarget)
        #expect(capabilities.readAndSetBounds)
        #expect(capabilities.readAndSetViewMode)
        #expect(capabilities.createWindow)
        #expect(capabilities.closeWindow)
        #expect(!capabilities.hasPublicTabModel)
    }

    @Test
    func detectsAnExplicitTabClass() {
        let source = "<class name=\"tab\"/>"

        #expect(FinderDictionaryInspector.inspect(source).hasPublicTabModel)
    }
}
