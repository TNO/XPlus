/*
 * Copyright (c) 2024, 2026 TNO-ESI
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 */
package nl.esi.xtext.common.lang.reporting;

import java.util.List;

import org.eclipse.emf.common.util.Diagnostic;

/**
 * A record that represents the outcome of some processing activity,
 * mimicking the {@link Diagnostic} interface and serializable with Gson.
 */
public record StatusReport(
    Severity severity,
    String message,
    String source,
    Integer code,
    String details,
    Integer startLine,
    Integer endLine,
    Integer offset,
    Integer length,
    String text,
    List<StatusReport> children
) {
    /**
     * Creates a new ValidationMessage with all fields.
     * 
     * The severity field will be automatically elevated to the highest severity found in the children list,
     * ensuring that the parent always reflects the most severe condition among its children.
     *
     * @param severity the initial severity level (will be elevated if children have higher severity)
     * @param message the message describing the situation
     * @param source the source identifier
     * @param code the source-specific identity code
     * @param details the details string (representing low-level exception information)
     * @param startLine the starting line number of the location
     * @param endLine the ending line number of the location
     * @param offset the character offset in the source
     * @param length the length of the located text
     * @param text the located text content
     * @param children the list of child validation messages (severity will be elevated based on these)
     */
    public StatusReport {
        // Calculate the highest severity from children
    	if (children != null && children.isEmpty()) {
            // Set children to null if empty
            children = null;
        }
        if (children != null) {
            Severity maxSeverity = severity;
            for (StatusReport child : children) {
                if (child != null && child.severity.value > maxSeverity.value) {
                    maxSeverity = child.severity;
                }
            }
            // Re-assign severity to the highest found
            severity = maxSeverity;
        }
    }

    /**
     * Returns a string representation of the severity level.
     *
     * @return a string describing the severity
     */
    public String getSeverityString() {
        return severity.name();
    }

    /**
     * Checks if this report indicates an error condition.
     *
     * @return true if severity is ERROR or CANCEL, false otherwise
     */
    public boolean isError() {
        return severity.isError();
    }

}