/**
 * Copyright (c) 2024, 2026 TNO-ESI
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 */
package nl.esi.xtext.common.lang.utilities

import java.util.Collections
import java.util.Map
import nl.esi.xtext.common.lang.base.Annotatable
import nl.esi.xtext.common.lang.base.Annotation
import nl.esi.xtext.common.lang.base.AnnotationBooleanValue
import nl.esi.xtext.common.lang.base.AnnotationDoubleValue
import nl.esi.xtext.common.lang.base.AnnotationLongValue
import nl.esi.xtext.common.lang.base.AnnotationStringValue
import nl.esi.xtext.common.lang.base.AnnotationValue

class AnnotationUtil {
    public static val String DEFAULT_PARAMETER = "value"

    private new() {
        // Empty
    }

    static def Map<String, Map<String, Object>> getAnnotations(Annotatable annotatable) {
        if (annotatable !== null) {
            return annotatable.annotations.toMap([name], [annotationValues])
        }
    }

    static def Annotation getAnnotation(Annotatable annotatable, String annotation) {
        if (annotatable !== null) {
            return annotatable.annotations.findFirst[name == annotation];
        }
    }

    static def Map<String, Object> getAnnotationValues(Annotatable annotatable, String annotation) {
        return annotatable.getAnnotation(annotation).annotationValues
    }

    static def Map<String, Object> getAnnotationValues(Annotation annotation) {
        if (annotation === null) {
            return Collections.emptyMap
        }
        return annotation.params.toMap([name ?: DEFAULT_PARAMETER], [get(value)])
    }

    static def AnnotationValue getAnnotationValue(Annotatable annotatable, String annotation) {
        return annotatable.getAnnotation(annotation).getAnnotationValue()
    }

    static def AnnotationValue getAnnotationValue(Annotatable annotatable, String annotation, String parameter) {
        return annotatable.getAnnotation(annotation).getAnnotationValue(parameter)
    }

    static def AnnotationValue getAnnotationValue(Annotation annotation) {
        return annotation.getAnnotationValue(DEFAULT_PARAMETER)
    }

    static def AnnotationValue getAnnotationValue(Annotation annotation, String parameter) {
        if (annotation !== null) {
            return annotation.params.findFirst[(name ?: DEFAULT_PARAMETER) == parameter]?.value
        }
    }

    static def Object get(AnnotationValue annotationValue) {
        return switch (annotationValue) {
            AnnotationLongValue: annotationValue.value
            AnnotationDoubleValue: annotationValue.value
            AnnotationStringValue: annotationValue.value
            AnnotationBooleanValue: annotationValue.value
            default: null
        }
    }

    static def long orElse(AnnotationValue annotationValue, long defaultValue) {
        return switch (annotationValue) {
            AnnotationLongValue: annotationValue.value
            AnnotationDoubleValue: annotationValue.value.longValue
            AnnotationStringValue: Long.parseLong(annotationValue.value)
            default: defaultValue
        }
    }

    static def double orElse(AnnotationValue annotationValue, double defaultValue) {
        return switch (annotationValue) {
            AnnotationLongValue: annotationValue.value.doubleValue
            AnnotationDoubleValue: annotationValue.value
            AnnotationStringValue: Double.parseDouble(annotationValue.value)
            default: defaultValue
        }
    }

    static def boolean orElse(AnnotationValue annotationValue, boolean defaultValue) {
        return switch (annotationValue) {
            AnnotationBooleanValue: annotationValue.value
            AnnotationStringValue: Boolean.parseBoolean(annotationValue.value)
            default: defaultValue
        }
    }

    static def String orElse(AnnotationValue annotationValue, String defaultValue) {
        return switch (annotationValue) {
            AnnotationLongValue: annotationValue.value.toString
            AnnotationDoubleValue: annotationValue.value.toString
            AnnotationBooleanValue: annotationValue.value.toString
            AnnotationStringValue: annotationValue.value
            default: defaultValue
        }
    }
}