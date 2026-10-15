/*
 * Copyright (c) 2024, 2026 TNO-ESI
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 */
package nl.esi.xtext.common.lang.conversion;

import java.util.regex.Pattern;

import org.eclipse.xtext.conversion.IValueConverter;
import org.eclipse.xtext.conversion.ValueConverterException;
import org.eclipse.xtext.nodemodel.INode;

/**
 * Value converter for the {@code ANNOTATION_ID} terminal.
 * <p>
 * The terminal includes the leading {@code '@'} (and an optional {@code '^'} escape) so that
 * annotation names are never lexed as keywords. This converter strips these prefixes when
 * reading, e.g. {@code "@suppress"} or {@code "@^suppress"} becomes {@code "suppress"},
 * and prepends {@code '@'} again when serializing.
 * </p>
 */
public class AnnotationIdValueConverter implements IValueConverter<String> {
	private static final String PREFIX = "@";

	private static final String ESCAPE = "^";

	private static final Pattern NAME_PATTERN = Pattern.compile("[a-zA-Z_][a-zA-Z_0-9]*");

	@Override
	public String toValue(final String string, final INode node) throws ValueConverterException {
		if (string == null) {
			return null;
		}
		if (!string.startsWith(PREFIX)) {
			throw new ValueConverterException("Expected annotation to start with " + PREFIX, node, null);
		}
		String value = string.substring(PREFIX.length());
		if (value.startsWith(ESCAPE)) {
			value = value.substring(ESCAPE.length());
		}
		if (!NAME_PATTERN.matcher(value).matches()) {
			throw new ValueConverterException("Invalid annotation name '" + string + "'", node, null);
		}
		return value;
	}

	@Override
	public String toString(final String value) throws ValueConverterException {
		if (value == null) {
			throw new ValueConverterException("Annotation name may not be null", null, null);
		}
		if (!NAME_PATTERN.matcher(value).matches()) {
			throw new ValueConverterException("Invalid annotation name '" + value + "'", null, null);
		}
		// No escape needed: '@' prefix already prevents keyword clashes
		return PREFIX + value;
	}
}
