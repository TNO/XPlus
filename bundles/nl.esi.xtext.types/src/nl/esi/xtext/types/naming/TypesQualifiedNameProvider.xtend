/**
 * Copyright (c) 2024, 2026 TNO-ESI
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 */
package nl.esi.xtext.types.naming

import nl.esi.xtext.types.types.TypeDecl
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.naming.DefaultDeclarativeQualifiedNameProvider
import org.eclipse.xtext.naming.QualifiedName

/**
 * Computes fully qualified names for {@link TypeDecl}s, taking nested type declarations
 * into account. A type declaration nested inside a {@code record} (or, transitively, inside
 * another nested type) is named by prefixing it with the qualified name of its containing
 * type, e.g. a type {@code B} nested in record {@code A} is named {@code A.B}. Nested types
 * are always public, i.e. they are always reachable via this qualified name, both from
 * within and from outside their containing record.
 * <p>
 * Top-level type declarations (i.e. not nested inside a record) keep their simple name as
 * their fully qualified name, as before.
 */
class TypesQualifiedNameProvider extends DefaultDeclarativeQualifiedNameProvider {

    override QualifiedName getFullyQualifiedName(EObject obj) {
        if (obj instanceof TypeDecl) {
            if (obj.name === null) {
                return null
            }
            val container = obj.eContainer
            val containerName = if (container instanceof TypeDecl) container.fullyQualifiedName else null
            return if (containerName !== null) containerName.append(obj.name) else QualifiedName.create(obj.name)
        }
        return super.getFullyQualifiedName(obj)
    }
}
