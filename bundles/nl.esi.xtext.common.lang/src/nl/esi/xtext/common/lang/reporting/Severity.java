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

/**
 * Enum representing the severity level of a validation message.
 */
public enum Severity {
    /**
     * Severity indicating everything is okay.
     */
    OK(0x0),

    /**
     * Severity indicating there is an informational message.
     */
    INFO(0x1),

    /**
     * Severity indicating there is a warning message.
     */
    WARNING(0x2),

    /**
     * Severity indicating there is an error message.
     */
    ERROR(0x4),

    /**
     * Severity indicating that the diagnosis was canceled.
     */
    CANCEL(0x8);

    /**
     * The numeric value representing this severity level.
     */
    public final int value;

    /**
     * Constructs a Severity with the given numeric value.
     *
     * @param value the numeric severity value
     */
    private Severity(int value) {
        this.value = value;
    }

    /**
     * Converts a numeric severity value to the corresponding Severity enum constant.
     *
     * @param value the numeric severity value
     * @return the corresponding Severity enum constant, defaults to OK if not found
     */
    public static Severity fromValue(int value) {
        for (Severity severity : Severity.values()) {
            if (severity.value == value) {
                return severity;
            }
        }
        return OK;
    }

    /**
     * Checks if this severity indicates an error condition.
     *
     * @return true if this is ERROR or CANCEL, false otherwise
     */
    public boolean isError() {
        return (this.value & (ERROR.value | CANCEL.value)) != 0;
    }

}
