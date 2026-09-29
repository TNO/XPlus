/**
 * Copyright (c) 2024, 2026 TNO-ESI
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 */
package nl.esi.xtext.types.generator

import java.io.Serializable
import java.util.ArrayList
import java.util.List
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors
class DataTypeOutlineEntry implements Serializable {
  public static val String NODE = "node"
  public static val String COLLECTION_ELEMENT = "collection-element"
  public static val String MAP_KEY = "map-key"
  public static val String MAP_VALUE = "map-value"
  public static val String RECORD_FIELD = "record-field"
  public static val String ENUM_LITERAL = "enum-literal"
  public static val String PRIMITIVE_BASED_ON = "primitive-based-on"
  public static val String RECORD = "Record"
  public static val String MAP = "Map"
  public static val String LIST = "List"
  public static val String ENUM = "Enum"

  String nodeType
  String id
  String name
  String label
  String kind
  List<DataTypeOutlineEntry> children

  new(String nodeType, String id, String name, String label, List<DataTypeOutlineEntry> children) {
    this(nodeType, id, name, label, null, children)
  }

  new(String nodeType, String id, String name, String label, String kind, List<DataTypeOutlineEntry> children) {
    this.nodeType = nodeType ?: NODE
    this.id = id
    this.name = name
    this.label = label
    this.kind = kind
    this.children = if(children === null) newArrayList() else new ArrayList(children)
  }
}
