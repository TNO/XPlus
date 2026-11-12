/**
 * Copyright (c) 2024, 2026 TNO-ESI
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 */
package nl.esi.xtext.expressions.utilities

import java.util.ArrayList
import java.util.Collection
import java.util.List
import java.util.Map
import java.util.Set
import nl.esi.xtext.expressions.expression.Expression
import nl.esi.xtext.expressions.expression.ExpressionAddition
import nl.esi.xtext.expressions.expression.ExpressionAnd
import nl.esi.xtext.expressions.expression.ExpressionAny
import nl.esi.xtext.expressions.expression.ExpressionBinary
import nl.esi.xtext.expressions.expression.ExpressionBracket
import nl.esi.xtext.expressions.expression.ExpressionConditional
import nl.esi.xtext.expressions.expression.ExpressionConstantBool
import nl.esi.xtext.expressions.expression.ExpressionConstantInt
import nl.esi.xtext.expressions.expression.ExpressionConstantReal
import nl.esi.xtext.expressions.expression.ExpressionConstantString
import nl.esi.xtext.expressions.expression.ExpressionDivision
import nl.esi.xtext.expressions.expression.ExpressionEnumLiteral
import nl.esi.xtext.expressions.expression.ExpressionEqual
import nl.esi.xtext.expressions.expression.ExpressionFactory
import nl.esi.xtext.expressions.expression.ExpressionFunctionCall
import nl.esi.xtext.expressions.expression.ExpressionGeq
import nl.esi.xtext.expressions.expression.ExpressionGreater
import nl.esi.xtext.expressions.expression.ExpressionLeq
import nl.esi.xtext.expressions.expression.ExpressionLess
import nl.esi.xtext.expressions.expression.ExpressionMap
import nl.esi.xtext.expressions.expression.ExpressionMapRW
import nl.esi.xtext.expressions.expression.ExpressionMaximum
import nl.esi.xtext.expressions.expression.ExpressionMinimum
import nl.esi.xtext.expressions.expression.ExpressionMinus
import nl.esi.xtext.expressions.expression.ExpressionModulo
import nl.esi.xtext.expressions.expression.ExpressionMultiply
import nl.esi.xtext.expressions.expression.ExpressionNEqual
import nl.esi.xtext.expressions.expression.ExpressionNot
import nl.esi.xtext.expressions.expression.ExpressionNullCoalescing
import nl.esi.xtext.expressions.expression.ExpressionNullLiteral
import nl.esi.xtext.expressions.expression.ExpressionOr
import nl.esi.xtext.expressions.expression.ExpressionPackage
import nl.esi.xtext.expressions.expression.ExpressionPlus
import nl.esi.xtext.expressions.expression.ExpressionPower
import nl.esi.xtext.expressions.expression.ExpressionRecord
import nl.esi.xtext.expressions.expression.ExpressionRecordAccess
import nl.esi.xtext.expressions.expression.ExpressionSubtraction
import nl.esi.xtext.expressions.expression.ExpressionVariable
import nl.esi.xtext.expressions.expression.ExpressionVector
import nl.esi.xtext.expressions.expression.NamedArgument
import nl.esi.xtext.expressions.expression.ParameterizedDecl
import nl.esi.xtext.expressions.expression.ParameterizedRef
import nl.esi.xtext.types.BasicTypes
import nl.esi.xtext.types.types.EnumTypeDecl
import nl.esi.xtext.types.types.GenericsTypeParam
import nl.esi.xtext.types.types.MapTypeConstructor
import nl.esi.xtext.types.types.MapTypeDecl
import nl.esi.xtext.types.types.RecordField
import nl.esi.xtext.types.types.RecordTypeDecl
import nl.esi.xtext.types.types.SimpleTypeDecl
import nl.esi.xtext.types.types.Type
import nl.esi.xtext.types.types.TypeObject
import nl.esi.xtext.types.types.TypeReference
import nl.esi.xtext.types.types.TypesFactory
import nl.esi.xtext.types.types.VectorTypeConstructor
import nl.esi.xtext.types.types.VectorTypeDecl
import nl.esi.xtext.types.utilities.TypeUtilities
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference

import static nl.esi.xtext.common.lang.utilities.EcoreUtil3.*

import static extension nl.esi.xtext.types.utilities.TypeUtilities.*
import static extension org.eclipse.emf.ecore.util.EcoreUtil.*

class ExpressionsUtilities {
    static extension val TypesFactory TYPES_FACTORY = TypesFactory.eINSTANCE
    static extension val ExpressionFactory EXPRESSION_FACTORY = ExpressionFactory.eINSTANCE

    def static Type asExprType(Type type) {
        return switch (type) {
            VectorTypeConstructor: createVectorTypeConstructor => [
                type = type.type
                dimensions += type.dimensions.copyAll
            ]
            MapTypeConstructor: createMapTypeConstructor => [
                type = type.type
                valueType = type.valueType.asExprType
            ]
            TypeReference: createTypeReference => [
                type = type.type
            ]
            default: throw new RuntimeException('Unsupported type: ' + type.typeName)
        }
    }

    def static Expression createDefaultValue(TypeObject typeObj, (RecordField)=>Boolean filter) {
        return switch (typeObj) {
            SimpleTypeDecl case typeObj.name == 'int': createExpressionConstantInt
            SimpleTypeDecl case typeObj.name == 'real': createExpressionConstantReal
            SimpleTypeDecl case typeObj.name == 'bool': createExpressionConstantBool
            SimpleTypeDecl: createExpressionConstantString => [ value = "" ]

            EnumTypeDecl: createExpressionEnumLiteral => [
                type = typeObj
                typeObj.literals.head
            ]

            RecordTypeDecl: createExpressionRecord => [
                type = typeObj
                for(field: typeObj.allFields.filter[filter.apply(it)]) {
                    fields += createField => [
                        recordField = field
                        exp = field.type.typeObject.createDefaultValue(filter)
                    ]
                }
            ]

            VectorTypeDecl: typeObj.constructor.createDefaultValue(filter)
            VectorTypeConstructor: createExpressionVector => [
                typeAnnotation = createTypeAnnotation => [ type = typeObj.asExprType ]
            ]

            MapTypeDecl: typeObj.constructor.createDefaultValue(filter)
            MapTypeConstructor: createExpressionMap => [
                typeAnnotation = createTypeAnnotation => [ type = typeObj.asExprType ]
            ]
        }
    }
    
        //Type computation. No checking is performed. If the type cannot be determined, null is returned
    def static TypeObject typeOf(Expression e) {
        if(e === null) return null
        switch(e){
            ExpressionConstantBool |
            ExpressionAnd |
            ExpressionOr |
            ExpressionNot |
            ExpressionEqual |
            ExpressionNEqual |
            ExpressionLess |
            ExpressionGreater |
            ExpressionLeq |
            ExpressionGeq : BasicTypes.getBoolType(e)
            ExpressionConstantInt |
            ExpressionModulo : BasicTypes.getIntType(e)
            ExpressionConstantReal : BasicTypes.getRealType(e)
            ExpressionAddition |
            ExpressionSubtraction |
            ExpressionDivision | 
            ExpressionMultiply |
            ExpressionPower |
            ExpressionMinimum |
            ExpressionMaximum : inferTypeBinaryArithmetic(e)
            ExpressionMinus |
            ExpressionPlus : {
                val t = e.sub.typeOf
                if(t.subTypeOf(BasicTypes.getIntType(e)) || t.subTypeOf(BasicTypes.getRealType(e)))
                    t
                else
                    null
            }
            ExpressionVariable : e.variable?.type.typeObject
            ExpressionConstantString : BasicTypes.getStringType(e)
            ExpressionBracket : e.sub?.typeOf
            ExpressionEnumLiteral : e.type
            ExpressionNullLiteral : BasicTypes.getAnyType(e)
            ExpressionRecord : e.type
            ExpressionRecordAccess : e.field?.type?.typeObject
            ExpressionAny : BasicTypes.getAnyType(e)
            ExpressionFunctionCall : e.inferActualReturnType.typeObject
            ExpressionVector : e.typeAnnotation?.type?.typeObject
            ExpressionMap : e.typeAnnotation?.type?.typeObject
            ExpressionMapRW : {
                val t = e.map.typeOf
                if(t !== null && t.mapType)
                    if(e.value !== null){
                        t
                    }else{
                        t.valueType
                    }
                else
                    null
            }
            ExpressionNullCoalescing: {
                e.left.typeOf.getCommonType(e.right.typeOf)
            }
            ExpressionConditional: {
                e.middle.typeOf.getCommonType(e.right.typeOf)
            }
        }
    }

    /**
     *  Resolve the actual return type
     */
    def static Type inferActualReturnType(ExpressionFunctionCall functionCall) {
        val returnType = functionCall.function.returnType
        val genericsTypeParams = getGenericsTypeParams(returnType)
        if (genericsTypeParams.empty) {
            return returnType
        }
        // Build a map from each generic type param to its resolved actual type
        val resolutionMap = newLinkedHashMap
        for (gtp : genericsTypeParams) {
            val resolved = gtp.getActualFunctionTypes(functionCall)
            if (resolved.size == 1) {
                // only resolve it if exactly one match is found
                resolutionMap.put(gtp, resolved.head)
            }
        }
        // Reconstruct the return type with generic params substituted
        return substituteGenerics(returnType, resolutionMap)
    }

    /**
     * Replace the template function param with the actual type
     */
    def static inferActualType(Type type, Expression arg){
        val genericsTypeParams = getGenericsTypeParams(type)
        if (genericsTypeParams.empty) {
            return type
        }
        val argType = arg.typeOf
        if (argType === null) return type
        val resolutionMap = newHashMap
        for (gtp : genericsTypeParams) {
            val matched = newLinkedHashSet
            collectMatchingTypes(type, argType, gtp, matched)
            if (matched.size == 1) {
                resolutionMap.put(gtp, matched.head.asType)
            }
        }
        return substituteGenerics(type, resolutionMap)
    }
    
    /**
     * Resolve the actual types of a generic type parameter from the arguments of a function call.
     * Both positional and named arguments are taken into account (see {@link #getFunctionArgs(ExpressionFunctionCall)}).
     */
    def static List<Type> getActualFunctionTypes(GenericsTypeParam type, ExpressionFunctionCall functionCall) {
        val result = newLinkedHashSet
        val args = functionCall.functionArgs
        val params = functionCall.function?.params ?: emptyList
        for (var i = 0; i < Math.min(args.size, params.size); i++) {
            val arg = args.get(i)
            if (arg !== null) {
                collectMatchingTypes(params.get(i).type, arg.typeOf, type, result)
            }
        }
        return result.map[asType].toList
    }

    def static List<Expression> getFunctionArgs(ExpressionFunctionCall efc){
        // don't validate here, that is part of the validator
        if (efc.function === null) {
            return List.of();
        }
        return getParameterArgs(efc, efc.function)
    }

    /**
     * Returns the single-valued, non-containment reference of {@code ref} that refers to a {@link ParameterizedDecl}
     * (e.g. {@code ExpressionFunctionCall.function}), or {@code null} if there is none.
     */
    def static EReference getParameterizedDeclReference(ParameterizedRef ref) {
        return ref.eClass.EAllReferences.findFirst[
            !containment && !many && ExpressionPackage.Literals.PARAMETERIZED_DECL.isSuperTypeOf(EReferenceType)
        ]
    }

    /**
     * Returns the {@link ParameterizedDecl} referred to by {@code ref} (possibly an unresolved proxy),
     * or {@code null} if it is not set.
     * @see #getParameterizedDeclReference(ParameterizedRef)
     */
    def static ParameterizedDecl getParameterizedDecl(ParameterizedRef ref) {
        val feature = ref.parameterizedDeclReference
        return feature === null ? null : ref.eGet(feature) as ParameterizedDecl
    }

    /**
     * Leniently maps the arguments of {@code ref} to the parameters of {@code decl}: positional arguments by index,
     * named arguments by name. Unbound parameters are padded with {@code null} and unknown named arguments are ignored;
     * the result may be longer than the parameter list if there are too many positional arguments.
     * Use {@link #bindArguments(ParameterizedRef, ParameterizedDecl)} to check whether the arguments match exactly.
     */
    def static List<Expression> getParameterArgs(ParameterizedRef ref, ParameterizedDecl decl){
        val result = new ArrayList(ref.args)
        val params = decl.params
        // Pad with nulls to match number of params
        while(result.size < params.size) {
            result.add(null)
        }

        // Build parameter name to index map for O(1) lookups
        val paramNameIndexMap = newLinkedHashMap
        for(var i = 0; i < params.size; i++) {
            paramNameIndexMap.put(params.get(i).name, i)
        }

        // Fill in named arguments
        for (na : ref.namedArgs){
            val ind = paramNameIndexMap.get(na.name)
            if (ind !== null){
                result.set(ind, na.arg)
            }
        }
        return result
    }

    /**
     * Binds the arguments of {@code ref} to the parameters of {@code decl}.
     * @see #bindArguments(ParameterizedDecl, List, List)
     */
    def static List<Expression> bindArguments(ParameterizedRef ref, ParameterizedDecl decl) {
        return bindArguments(decl, ref.args, ref.namedArgs)
    }

    /**
     * Strictly binds arguments to the parameters of {@code decl}: positional arguments by index, named arguments by name.
     * Returns the argument per parameter (in parameter order), or {@code null} if the arguments cannot be bound, i.e.
     * there are more positional arguments than parameters, a named argument does not match a parameter name,
     * a named argument refers to a parameter that is already bound, or a parameter remains unbound.
     * <p>
     * In contrast to {@link #getParameterArgs(ParameterizedRef, ParameterizedDecl)} this does not pad unbound parameters with
     * {@code null}, so it can be used to decide whether a declaration matches at all (e.g. overload resolution).
     */
    def static List<Expression> bindArguments(ParameterizedDecl decl, List<Expression> args, List<NamedArgument> namedArgs) {
        val paramNames = decl.params.map[name]
        if (args.size > paramNames.size) {
            return null
        }
        val List<Expression> result = newArrayList(args)
        while (result.size < paramNames.size) {
            result.add(null)
        }
        for (na : namedArgs) {
            val index = paramNames.indexOf(na.name)
            if (index < 0 || result.get(index) !== null) {
                return null
            }
            result.set(index, na.arg)
        }
        return result.contains(null) ? null : result
    }

    private def static TypeObject inferTypeBinaryArithmetic(ExpressionBinary e){
        val leftType = e.left.typeOf
        val rightType = e.right.typeOf
        switch(e){
            ExpressionAddition : {
                if(leftType.subTypeOf(BasicTypes.getIntType(e)) && rightType.subTypeOf(BasicTypes.getIntType(e))) return BasicTypes.getIntType(e)
                if(leftType.subTypeOf(BasicTypes.getRealType(e)) && rightType.subTypeOf(BasicTypes.getRealType(e))) return BasicTypes.getRealType(e)
                if(leftType.subTypeOf(BasicTypes.getStringType(e)) && rightType.subTypeOf(BasicTypes.getStringType(e))) return BasicTypes.getStringType(e)
                return null
            }
            ExpressionSubtraction |
            ExpressionDivision |
            ExpressionPower | 
            ExpressionMultiply |
            ExpressionMinimum |
            ExpressionMaximum : {
                if(leftType.subTypeOf(BasicTypes.getIntType(e)) && rightType.subTypeOf(BasicTypes.getIntType(e))) return BasicTypes.getIntType(e)
                if(leftType.subTypeOf(BasicTypes.getRealType(e)) && rightType.subTypeOf(BasicTypes.getRealType(e))) return BasicTypes.getRealType(e)
                return null
            }
            default : null
        }
    }

    def static List<GenericsTypeParam> getGenericsTypeParams(Type type) {
        val seen = newLinkedHashSet
        val result = newLinkedHashSet
        collect(type, GenericsTypeParam, seen, result)
        return result.toList
    }

    private def static <T extends EObject> void collect(EObject object, Class<T> clazz, Set<EObject> seen, Collection<T> result) {
        if( object === null) {
            return
        }
        if (clazz.isInstance(object)) {
            result.add(clazz.cast(object))
            return
        }
        if (seen.add(object)){
            object.eContents.forEach[collect(it, clazz, seen, result)]
            object.eCrossReferences.forEach[collect(it, clazz, seen, result)]
        }
    }

    /**
     * Recursively substitute generic type parameters in a type structure.
     */
    private def static Type substituteGenerics(Type targetType, Map<GenericsTypeParam, Type> resolutionMap) {
        if (targetType === null) return null
        return switch (targetType) {
            VectorTypeConstructor: createVectorTypeConstructor => [
                val substituteType = resolutionMap.get(targetType.type)
                type = substituteGenerics(targetType.typeObject.elementType.asType, resolutionMap).type
                if(substituteType.isVectorType) {
                    dimensions += substituteType.dimensions.copyAll
                }
                dimensions += targetType.dimensions.copyAll
            ]
            MapTypeConstructor: createMapTypeConstructor => [
                type = substituteGenerics(targetType.typeObject.keyType.asType, resolutionMap).type
                valueType = substituteGenerics(targetType.typeObject.valueType.asType, resolutionMap).asExprType
            ]
            TypeReference: {
                // resolve generics or just the original type decl
                return resolutionMap.getOrDefault(targetType.type,targetType)
            }
            default:
               targetType
        }
    }

    /**
     * Recursively walk the declared parameter type and the actual argument type in parallel,
     * collecting actual types that correspond to the given generic type parameter.
     */
    private def static void collectMatchingTypes(Type declaredType, TypeObject actualType, GenericsTypeParam genParam, Set<TypeObject> result) {
        if (declaredType === null || actualType === null) {
            return
        }
        if (declaredType.isMapType && actualType.isMapType) {
            collectMatchingTypes(declaredType.typeObject.keyType.asType, actualType.keyType, genParam, result)
            collectMatchingTypes(declaredType.typeObject.valueType.asType, actualType.valueType, genParam, result)
        } else if (declaredType.isVectorType && actualType.isVectorType) {
            collectMatchingTypes(declaredType.typeObject.elementType.asType, actualType.elementType, genParam, result)
        } else if (declaredType.type == genParam) {
            result.add(actualType)
        }
    }

    def static CharSequence generateDefaultValue(TypeObject t, (RecordField)=>Boolean filter) {
        switch (t) {
            SimpleTypeDecl: {
                if(t.name.equals("int")) return '''0'''
                if(t.name.equals("real")) return '''0.0'''
                if(t.name.equals("bool")) return '''true'''
                if(t.name.equals("string")) return '''""'''
                ""
            }
            EnumTypeDecl: serialize(t) + "::" + t.literals.get(0).name
            RecordTypeDecl: '''«serialize(t)»{«FOR f : TypeUtilities::getAllFields(t).filter[filter.apply(it)] SEPARATOR ', '»«f.name» = «generateDefaultValue(f.type.typeObject, filter)»«ENDFOR»}'''
            VectorTypeDecl: '''<«serialize(t)»>[]'''
            VectorTypeConstructor: '''<«serialize(t)»>[]'''
            MapTypeDecl: '''<«serialize(t)»>{}'''
            MapTypeConstructor: '''<«serialize(t)»>{}'''
            default:
                ""
        }
    }
}