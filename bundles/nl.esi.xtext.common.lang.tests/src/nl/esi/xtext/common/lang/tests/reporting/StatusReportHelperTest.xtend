/**
 * Copyright (c) 2024, 2026 TNO-ESI
 * 
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 * 
 * SPDX-License-Identifier: EPL-2.0
 */
package nl.esi.xtext.common.lang.tests.reporting

import com.google.inject.Inject
import java.util.List
import nl.esi.xtext.common.lang.base.ModelContainer
import nl.esi.xtext.common.lang.tests.BaseInjectorProvider
import nl.esi.xtext.common.lang.reporting.Severity
import nl.esi.xtext.common.lang.reporting.StatusReportHelper
import nl.esi.xtext.common.lang.reporting.StatusReport
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.extensions.InjectionExtension
import org.eclipse.xtext.testing.util.ParseHelper
import org.junit.jupiter.api.Assertions
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.^extension.ExtendWith

/**
 * Test cases for StatusReportHelper utility class.
 * Tests validation of EObjects and Resources using EMF Diagnostician.
 */
@ExtendWith(InjectionExtension)
@InjectWith(BaseInjectorProvider)
class StatusReportHelperTest {
    @Inject
    ParseHelper<ModelContainer> parseHelper

    /**
     * Test validation of a valid model (no imports, just a simple import statement).
     * Expected: validation should succeed with OK severity.
     */
    @Test
    def void testValidateValidModel() {
        val result = parseHelper.parse('''
            import "dummy.base_lang"
        ''')
        Assertions.assertNotNull(result)

        val StatusReport = StatusReportHelper.validate(result)
        Assertions.assertNotNull(StatusReport)
        Assertions.assertEquals(Severity.OK, StatusReport.severity, "Validation should succeed with OK severity")
        Assertions.assertNotNull(StatusReport.message)
    }

    /**
     * Test validation of a valid model with named elements.
     * Expected: validation should succeed without errors.
     */
    @Test
    def void testValidateModelWithNamedElements() {
        val result = parseHelper.parse('''
            import "dummy.base_lang"
            TestElement
            AnotherElement
        ''')
        Assertions.assertNotNull(result)

        val StatusReport = StatusReportHelper.validate(result)
        Assertions.assertNotNull(StatusReport)
        Assertions.assertFalse(StatusReport.isError(), "Validation should not report errors")
        Assertions.assertTrue(StatusReport.severity == Severity.OK, "Validation should be OK")
    }

    /**
     * Test validation of a model resource (via eResource).
     * Expected: validation should complete successfully.
     */
    @Test
    def void testValidateResource() {
        val result = parseHelper.parse('''
            import "dummy.base_lang"
            Same
            Same
        ''')
        Assertions.assertNotNull(result)
        val resource = result.eResource
        Assertions.assertNotNull(resource)

        val StatusReport = StatusReportHelper.validate(resource)
        Assertions.assertNotNull(StatusReport)
        Assertions.assertNotNull(StatusReport.message)
        Assertions.assertTrue(StatusReport.message.length > 0, "Validation message should not be empty")
        Assertions.assertTrue(StatusReport.children.size > 1, "There should be validation errors")
        Assertions.assertTrue(StatusReport.children.get(0).message().contains("Duplicate"),
            "Expected duplicate validation error")
    }

    /**
     * Test validation of a model resource (via eResource).
     * Expected: validation should complete successfully.
     */
    @Test
    def void testGson() {
        val result = parseHelper.parse('''
            import "dummy.base_lang"
            Same
            Same
        ''')
        Assertions.assertNotNull(result)
        val resource = result.eResource
        Assertions.assertNotNull(resource)

        val statusReport = StatusReportHelper.validate(resource)

        // serialize with gson
        val json = StatusReportHelper.toJson(statusReport)
        val statusReport2 = StatusReportHelper.fromJson(json);
        Assertions.assertEquals(statusReport, statusReport2);

    }

    /**
     * Test that Severity enum contains proper severity constants.
     * Expected: all severity constants should be accessible via Severity enum.
     */
    @Test
    def void testStatusReportSeverityConstants() {
        Assertions.assertEquals(0x0, Severity.OK.value)
        Assertions.assertEquals(0x1, Severity.INFO.value)
        Assertions.assertEquals(0x2, Severity.WARNING.value)
        Assertions.assertEquals(0x4, Severity.ERROR.value)
        Assertions.assertEquals(0x8, Severity.CANCEL.value)
    }

    /**
     * Test StatusReport.isError() method.
     * Expected: should return true for ERROR and CANCEL, false for others.
     */
    @Test
    def void testStatusReportIsError() {
        val okMessage = createStatusReport(Severity.OK, "Test", "source", 0)
        Assertions.assertFalse(okMessage.isError(), "OK should not be an error")

        val errorMessage = createStatusReport(Severity.ERROR, "Test", "source", 0)
        Assertions.assertTrue(errorMessage.isError(), "ERROR should be an error")

        val cancelMessage = createStatusReport(Severity.CANCEL, "Test", "source", 0)
        Assertions.assertTrue(cancelMessage.isError(), "CANCEL should be an error")
    }

    /**
     * Test that StatusReport is a record with serializable fields.
     * Expected: all fields should be accessible and non-null where applicable.
     */
    @Test
    def void testStatusReportFields() {
        val message = createStatusReport(
            Severity.INFO,
            "Test message",
            "test.source",
            42,
            "Some details about the validation",
            1,
            2,
            3,
            4,
            "5"
        )

        Assertions.assertEquals(Severity.INFO, message.severity())
        Assertions.assertEquals("Test message", message.message())
        Assertions.assertEquals("test.source", message.source())
        Assertions.assertEquals(1, message.startLine())
        Assertions.assertEquals(2, message.endLine())
        Assertions.assertEquals(3, message.offset())
        Assertions.assertEquals(4, message.length())
        Assertions.assertEquals("5", message.text())
        Assertions.assertEquals(42, message.code())
        Assertions.assertEquals("Some details about the validation", message.details())
        Assertions.assertNull(message.children())
    }

    /**
     * Test that severity is elevated to the highest severity found in children.
     * Expected: parent severity should be elevated from OK to ERROR when children contain ERROR.
     */
    @Test
    def void testSeverityElevationFromChildren() {
        // Create child messages with different severities
        val child1 = createStatusReport(Severity.WARNING, "Warning message", "source1", 1)
        val child2 = createStatusReport(Severity.ERROR, "Error message", "source2", 2)
        val child3 = createStatusReport(Severity.INFO, "Info message", "source3", 3)

        // Create parent with OK severity but ERROR children
        val parent = createStatusReport(Severity.OK, #[child1, child2, child3])

        // Verify severity was elevated to ERROR (the highest in children)
        Assertions.assertEquals(Severity.ERROR, parent.severity(), "Parent severity should be elevated to ERROR")
        Assertions.assertTrue(parent.isError(), "Parent should be an error")
    }

    /**
     * Test that severity is elevated to the highest severity when it's the minimum initially.
     * Expected: parent severity should be elevated from INFO to CANCEL when children contain CANCEL.
     */
    @Test
    def void testSeverityElevationToCancel() {
        // Create child with CANCEL severity
        val child = createStatusReport(Severity.CANCEL, "Cancelled", "source", 1)

        // Create parent with INFO severity
        val parent = createStatusReport(Severity.INFO, #[child])

        // Verify severity was elevated to CANCEL (the highest possible)
        Assertions.assertEquals(Severity.CANCEL, parent.severity(), "Parent severity should be elevated to CANCEL")
        Assertions.assertTrue(parent.isError(), "Parent should be an error (CANCEL is error)")
    }

    /**
     * Test that severity remains unchanged when parent has higher severity than children.
     * Expected: parent severity should remain ERROR when children are only WARNING.
     */
    @Test
    def void testSeverityRemainsWhenHigherThanChildren() {
        // Create children with WARNING severity
        val child1 = createStatusReport(Severity.WARNING, "Warning 1", "source1", 1)
        val child2 = createStatusReport(Severity.WARNING, "Warning 2", "source2", 2)

        // Create parent with ERROR severity (higher than children)
        val parent = createStatusReport(Severity.ERROR, #[child1, child2])

        // Verify severity remains ERROR
        Assertions.assertEquals(Severity.ERROR, parent.severity(), "Parent severity should remain ERROR")
    }

    /**
     * Test that severity is not modified when children is null or empty.
     * Expected: severity should remain unchanged.
     */
    @Test
    def void testSeverityWithNullOrEmptyChildren() {
        // Test with null children
        val parentWithNull = createStatusReport(Severity.INFO, null)
        Assertions.assertEquals(Severity.INFO, parentWithNull.severity(),
            "Severity should remain INFO with null children")

        // Test with empty children
        val parentWithEmpty = createStatusReport(Severity.WARNING, #[])
        Assertions.assertEquals(Severity.WARNING, parentWithEmpty.severity(),
            "Severity should remain WARNING with empty children")
    }

    /**
     * Factory method to create a StatusReport with only the needed arguments.
     * Defaults for location fields: startLine=0, endLine=0, offset=0, length=0, text=""
     */
    private def static StatusReport createStatusReport(
        Severity severity,
        String message,
        String source,
        int code
    ) {
        return new StatusReport(severity, message, source, code, null, null, null, null, null, null, null)
    }

    /**
     * Factory method with location parameters
     */
    private def static StatusReport createStatusReport(
        Severity severity,
        String message,
        String source,
        int code,
        String details,
        int startLine,
        int endLine,
        int offset,
        int length,
        String text
    ) {
        return new StatusReport(severity, message, source, code, details, startLine, endLine, offset, length,
            text, null)
    }

    /**
     * Factory method with only severity and children.
     * All other fields use defaults: message="", source="", code=0, details=null, 
     * startLine=0, endLine=0, offset=0, length=0, text=""
     */
    private def static StatusReport createStatusReport(
        Severity severity,
        List<StatusReport> children
    ) {
        return new StatusReport(severity, "", "", 0, null, 0, 0, 0, 0, "", children)
    }

}
