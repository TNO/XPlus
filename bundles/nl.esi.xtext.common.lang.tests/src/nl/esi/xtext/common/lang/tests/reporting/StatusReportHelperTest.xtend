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
import nl.esi.xtext.common.lang.reporting.Location
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

        val statusReport = StatusReportHelper.validate(result)
        Assertions.assertNotNull(statusReport)
        Assertions.assertEquals(Severity.OK, statusReport.getSeverityLevel(), "Validation should succeed with OK severity")
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

        val statusReport = StatusReportHelper.validate(result)
        Assertions.assertNotNull(statusReport)
        Assertions.assertFalse(statusReport.isError(), "Validation should not report errors")
        Assertions.assertTrue(statusReport.getSeverityLevel() == Severity.OK, "Validation should be OK")
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

        val statusReport = StatusReportHelper.validate(resource)
        Assertions.assertNotNull(statusReport)
        Assertions.assertTrue(statusReport.getChildReports().isPresent(), "There should be validation errors")
        Assertions.assertTrue(statusReport.getChildReports().get().size > 0, "There should be child reports")
    }

    /**
     * Test GSON serialization/deserialization.
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
        val statusReport2 = StatusReportHelper.fromJson(json)
        Assertions.assertEquals(statusReport.getSeverityLevel(), statusReport2.getSeverityLevel())
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
        val okMessage = createStatusReport(Severity.OK, "Test", null)
        Assertions.assertFalse(okMessage.isError(), "OK should not be an error")

        val errorMessage = createStatusReport(Severity.ERROR, "Test", null)
        Assertions.assertTrue(errorMessage.isError(), "ERROR should be an error")

        val cancelMessage = createStatusReport(Severity.CANCEL, "Test", null)
        Assertions.assertTrue(cancelMessage.isError(), "CANCEL should be an error")
    }

    /**
     * Test that StatusReport fields are accessible and correct.
     */
    @Test
    def void testStatusReportFields() {
        var locations = newArrayList(new Location("test.source", 1, 2, 3, 4, "5"))
        var statusReport = new StatusReport(
            null,
            Severity.INFO,
            "Test message",
            42,
            "Some details about the validation",
            locations,
            null,
            null
        )

        Assertions.assertEquals(Severity.INFO, statusReport.getSeverityLevel())
        Assertions.assertTrue(statusReport.getLocations().isPresent())
        var loc = statusReport.getLocations().get().get(0)
        Assertions.assertEquals(1, loc.startLine().intValue())
        Assertions.assertEquals(2, loc.endLine().intValue())
        Assertions.assertEquals(3, loc.offset().intValue())
        Assertions.assertEquals(4, loc.length().intValue())
        Assertions.assertEquals("5", loc.text())
        Assertions.assertTrue(statusReport.getDetails().isPresent())
        Assertions.assertEquals("Some details about the validation", statusReport.getDetails().get())
    }

    /**
     * Test that severity is elevated to the highest severity found in children.
     * Expected: parent severity should be elevated from OK to ERROR when children contain ERROR.
     */
    @Test
    def void testSeverityElevationFromChildren() {
        // Create child messages with different severities
        val child1 = createStatusReport(Severity.WARNING, "Warning message", null)
        val child2 = createStatusReport(Severity.ERROR, "Error message", null)
        val child3 = createStatusReport(Severity.INFO, "Info message", null)

        // Create parent with OK severity but ERROR children
        val parent = new StatusReport(null, Severity.OK, "test", null, null, null, #[child1, child2, child3], null)

        // Verify severity was elevated to ERROR (the highest in children)
        Assertions.assertEquals(Severity.ERROR, parent.getSeverityLevel(), "Parent severity should be elevated to ERROR")
        Assertions.assertTrue(parent.isError(), "Parent should be an error")
    }

    /**
     * Test that severity is elevated to the highest severity when it's the minimum initially.
     * Expected: parent severity should be elevated from INFO to CANCEL when children contain CANCEL.
     */
    @Test
    def void testSeverityElevationToCancel() {
        // Create child with CANCEL severity
        val child = createStatusReport(Severity.CANCEL, "Cancelled", null)

        // Create parent with INFO severity
        val parent = new StatusReport(null, Severity.INFO, "test", null, null, null, #[child], null)

        // Verify severity was elevated to CANCEL (the highest possible)
        Assertions.assertEquals(Severity.CANCEL, parent.getSeverityLevel(), "Parent severity should be elevated to CANCEL")
        Assertions.assertTrue(parent.isError(), "Parent should be an error (CANCEL is error)")
    }

    /**
     * Test that severity remains unchanged when parent has higher severity than children.
     * Expected: parent severity should remain ERROR when children are only WARNING.
     */
    @Test
    def void testSeverityRemainsWhenHigherThanChildren() {
        // Create children with WARNING severity
        val child1 = createStatusReport(Severity.WARNING, "Warning 1", null)
        val child2 = createStatusReport(Severity.WARNING, "Warning 2", null)

        // Create parent with ERROR severity (higher than children)
        val parent = new StatusReport(null, Severity.ERROR, "test", null, null, null, #[child1, child2], null)

        // Verify severity remains ERROR
        Assertions.assertEquals(Severity.ERROR, parent.getSeverityLevel(), "Parent severity should remain ERROR")
    }

    /**
     * Test that severity is not modified when children is null or empty.
     * Expected: severity should remain unchanged.
     */
    @Test
    def void testSeverityWithNullOrEmptyChildren() {
        // Test with null children
        val parentWithNull = new StatusReport(null, Severity.INFO, "test", null, null, null, null, null)
        Assertions.assertEquals(Severity.INFO, parentWithNull.getSeverityLevel(),
            "Severity should remain INFO with null children")

        // Test with empty children
        val parentWithEmpty = new StatusReport(null, Severity.WARNING, "test", null, null, null, #[], null)
        Assertions.assertEquals(Severity.WARNING, parentWithEmpty.getSeverityLevel(),
            "Severity should remain WARNING with empty children")
    }

    /**
     * Factory method to create a StatusReport with simple parameters.
     */
    private def static StatusReport createStatusReport(
        Severity severity,
        String message,
        List<StatusReport> children
    ) {
        return new StatusReport(null, severity, message, null, null, null, children, null)
    }

}