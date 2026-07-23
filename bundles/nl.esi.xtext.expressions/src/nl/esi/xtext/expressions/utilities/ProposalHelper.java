/*
 * Copyright (c) 2024, 2026 TNO-ESI
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 */
package nl.esi.xtext.expressions.utilities;

import static nl.esi.xtext.types.utilities.TypeUtilities.getAllFields;

import java.util.List;
import java.util.function.Predicate;
import java.util.stream.Collectors;

import org.eclipse.emf.ecore.util.EcoreUtil;

import com.google.common.base.Predicates;

import nl.esi.xtext.expressions.expression.TypeAnnotation;
import nl.esi.xtext.types.types.EnumTypeDecl;
import nl.esi.xtext.types.types.MapTypeConstructor;
import nl.esi.xtext.types.types.MapTypeDecl;
import nl.esi.xtext.types.types.RecordField;
import nl.esi.xtext.types.types.RecordTypeDecl;
import nl.esi.xtext.types.types.SimpleTypeDecl;
import nl.esi.xtext.types.types.Type;
import nl.esi.xtext.types.types.TypeDecl;
import nl.esi.xtext.types.types.TypeReference;
import nl.esi.xtext.types.types.VectorTypeConstructor;
import nl.esi.xtext.types.types.VectorTypeDecl;
import nl.esi.xtext.types.utilities.TypeUtilities;

public class ProposalHelper {
	public static String getTypeName(Type type) {
		return TypeUtilities.getTypeName(type);
	}
	
	public static String getTypeName(TypeAnnotation typeAnn) {
		final Type type = typeAnn.getType();
		if (type instanceof TypeReference) {
			return TypeUtilities.getTypeName(type.getType());
		} else if (type instanceof VectorTypeConstructor vecType) {
			return TypeUtilities.getTypeName(TypeUtilities.getElementType(vecType));
		} else if (type instanceof MapTypeConstructor) {
			return TypeUtilities.getTypeName(type).replaceFirst("^map<", "map.entry<");
		}
		return null;
	}

	public static String defaultValue(TypeAnnotation typeAnn, String targetName) throws UnsupportedTypeException {
		return createDefaultValueEntry(typeAnn.getType(), targetName, "", Predicates.alwaysTrue());
	}

	public static String defaultValue(TypeAnnotation typeAnn, String targetName, Predicate<? super RecordField> filter) throws UnsupportedTypeException {
		return createDefaultValueEntry(typeAnn.getType(), targetName, "", filter);
	}

	public static String defaultValue(Type type, String targetName) throws UnsupportedTypeException {
		return createDefaultValue(type, targetName, "", Predicates.alwaysTrue());
	}

	public static String defaultValue(Type type, String targetName, Predicate<? super RecordField> filter) throws UnsupportedTypeException {
		return createDefaultValue(type, targetName, "", filter);
	}

	private static String createDefaultValue(Type type, String targetName, String indent, Predicate<? super RecordField> filter) throws UnsupportedTypeException {
		if (type instanceof TypeReference) {
			return createDefaultValueEntry(type, targetName, indent, filter);
		} else if (type instanceof VectorTypeConstructor) {
			return "<" + getTypeName(type) + ">[]";
		} else if (type instanceof MapTypeConstructor) {
			return "<" + getTypeName(type) + ">{}";
		}
		throw new UnsupportedTypeException(type);
	}

	private static String createDefaultValueEntry(Type type, String targetName, String indent, Predicate<? super RecordField> filter) throws UnsupportedTypeException {
		if (type instanceof TypeReference) {
			return createDefaultValue(type.getType(), targetName, indent, filter);
		} else if (type instanceof VectorTypeConstructor vecType) {
			if (vecType.getDimensions().size() > 1) {
				return createDefaultValue(getOuterDimension(vecType), null, indent, filter);
			}
			return createDefaultValue(type.getType(), targetName, indent, filter);
		} else if (type instanceof MapTypeConstructor mapType) {
			String key = createDefaultValue(type.getType(), null, indent, filter);
			String value = createDefaultValue(mapType.getValueType(), null, indent, filter);
			return key + " -> " + value;
		}
		throw new UnsupportedTypeException(type);
	}
	
	private static Type getOuterDimension(VectorTypeConstructor vectorType) {
		VectorTypeConstructor outerDimension = EcoreUtil.copy(vectorType);
		outerDimension.getDimensions().removeLast();
		return outerDimension;
	}

	private static String createDefaultValue(TypeDecl type, String targetName, String indent, Predicate<? super RecordField> filter) throws UnsupportedTypeException {
		if (type instanceof SimpleTypeDecl simpleType) {
			if (simpleType.getBase() != null) return createDefaultValue(simpleType.getBase(), targetName, indent, filter);
			else if (simpleType.getName().equals("int")) return "0";
			else if (simpleType.getName().equals("real")) return "0.0";
			else if (simpleType.getName().equals("bool")) return "true";
			else if (simpleType.getName().equals("string")) return "\"\"";
			else return "\"\""; // Custom types without base (e.g. type DateTime)
		} else if (type instanceof VectorTypeDecl) {
			return "[]";
		} else if (type instanceof EnumTypeDecl enumType) {
			return String.format("%s::%s", enumType.getName(), enumType.getLiterals().get(0).getName());
		} else if (type instanceof MapTypeDecl) {
			return "{}";
		} else if (type instanceof RecordTypeDecl recType) {
			List<RecordField> recFields = getAllFields(recType).stream().filter(filter).toList();
			if (recFields.size() > 1) {
				String fieldIndent = indent + "\t";
				String value = recFields.stream()
					.map(f -> String.format("%s%s = %s", fieldIndent, f.getName(), createDefaultValue(f.getType(), f.getName(), fieldIndent, filter)))
					.collect(Collectors.joining(",\n"));
				return String.format("%s {\n%s\n%s}", type.getName(), value, indent);
			} else {
				String value = recFields.stream()
					.map(f -> String.format("%s = %s", f.getName(), createDefaultValue(f.getType(), f.getName(), indent, filter)))
					.collect(Collectors.joining(",\n"));
				return String.format("%s { %s }", type.getName(), value);
			}
		} 
		
		throw new UnsupportedTypeException(type);
	}
}
