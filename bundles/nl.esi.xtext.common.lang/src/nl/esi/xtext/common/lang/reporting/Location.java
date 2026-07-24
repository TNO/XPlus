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
 * A record representing a location in source code or text.
 * Captures details such as line numbers, character offset, length, and text content.
 */
public record Location(
    String source,
    Integer startLine,
    Integer endLine,
    Integer offset,
    Integer length,
    String text
) {
    // Record with no additional implementation needed
}
