/*
 * Copyright (c) 2024, 2026 TNO-ESI
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 */
package nl.esi.xtext.common.lang.utilities;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

import nl.esi.xtext.common.lang.base.Annotation;
import nl.esi.xtext.common.lang.base.AnnotationParam;
import nl.esi.xtext.common.lang.base.HasAnnotations;

public class AnnotationUtil {
	private AnnotationUtil() {
		// private constructor to prevent instantiation
	}

	public static Map<String, Map<String, Object>> getAnnotations(HasAnnotations annotatedElement) {
		return annotatedElement.getAnnotations().stream()
			.collect(Collectors.toMap(Annotation::getName, AnnotationUtil::toMap, (a, b) -> a, LinkedHashMap::new));
	}

	public static Map<String, Object> getAnnotations(HasAnnotations annotatedElement, String key) {
		var anno = annotatedElement.getAnnotations().stream().filter(a -> a.getName().equals(key)).findFirst();
		if (anno.isPresent()) {
			return toMap(anno.get());
		}
		return Map.of();
	}
	
	public static Map<String, Object> toMap(Annotation annotation) {
		return annotation.getParams().stream().collect(
			Collectors.toMap(AnnotationParam::getName, it->toObject(it.getValue()), (a, b) -> a, LinkedHashMap::new));
	}

	public static String getAsString(HasAnnotations annotatedElement, String key) {
		return getAsString(annotatedElement, key, null);
	}

	public static Boolean getAsBoolean(HasAnnotations annotatedElement, String key) {
		return getAsBoolean(annotatedElement, key, null);
	}

    public static Integer getAsInteger(HasAnnotations annotatedElement, String key) {
		return getAsInteger(annotatedElement, key, null);
	}
    
    public static Double getAsDouble(HasAnnotations annotatedElement, String key) {
    	return getAsDouble(annotatedElement, key, null);
    }

	public static String getAsString(HasAnnotations annotatedElement, String key, String defaultValue) {
		return getAnnotationValue(annotatedElement, key).map(AnnotationUtil::strip).orElse(defaultValue);
	}

	public static Boolean getAsBoolean(HasAnnotations annotatedElement, String key, Boolean defaultValue) {
		return getAnnotationValue(annotatedElement, key).map(Boolean::valueOf).orElse(defaultValue);
	}

	public static Integer getAsInteger(HasAnnotations annotatedElement, String key, Integer defaultValue) {
		return getAnnotationValue(annotatedElement, key).map(Integer::valueOf).orElse(defaultValue);
	}

	public static Double getAsDouble(HasAnnotations annotatedElement, String key, Double defaultValue) {
		return getAnnotationValue(annotatedElement, key).map(Double::valueOf).orElse(defaultValue);
	}

	private static Optional<String> getAnnotationValue(HasAnnotations annotatedElement, String key) {
		return annotatedElement.getAnnotations().stream().filter(a -> a.getName().equals(key)).findFirst()
				.filter(a -> !a.getParams().isEmpty()).map(a -> a.getParams().get(0).getValue());
	}
	
	private static String strip(String str){
		if (str != null && str.startsWith("\"") && str.endsWith("\"")) {
			return str.substring(1, str.length() - 1);
		}
		return str;
	}
	private static final Object toObject(String str) {
		if (str == null){
			return null;
		}
		if (str.startsWith("\"") && str.endsWith("\"")) {
			return str.substring(1, str.length() - 1);
		}
		try {
			return Integer.valueOf(str.toString());
		} catch (NumberFormatException e) {
			try {
				return Double.valueOf(str.toString());
			} catch (NumberFormatException e1) {
				if (str.equalsIgnoreCase("true") || str.equalsIgnoreCase("false")) {
					return Boolean.valueOf(str.toString());
				}
			}
		}
		throw new IllegalArgumentException("Cannot convert string to object: " + str);
	}

}
