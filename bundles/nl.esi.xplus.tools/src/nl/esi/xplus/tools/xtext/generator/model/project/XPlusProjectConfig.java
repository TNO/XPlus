/*
 * Copyright (c) 2024, 2026 TNO-ESI
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 */
package nl.esi.xplus.tools.xtext.generator.model.project;

import java.util.List;
import java.util.Objects;
import java.util.stream.Stream;

import org.eclipse.xtext.xtext.generator.model.project.BundleProjectConfig;
import org.eclipse.xtext.xtext.generator.model.project.StandardProjectConfig;
import org.eclipse.xtext.xtext.generator.model.project.SubProjectConfig;

public class XPlusProjectConfig extends StandardProjectConfig {
	
	private BundleProjectConfig edit = new BundleProjectConfig();
	
	public List<? extends SubProjectConfig> getAllProjects() {
		return Stream.concat(super.getAllProjects().stream(), Stream.of(edit)).toList();
	}
	
	protected String computeName(SubProjectConfig project) {
		if (Objects.equals(project, edit)) {
			return getBaseName() + ".edit";
		}
		return super.computeName(project);
	}
	
	public BundleProjectConfig getEdit() {
		return edit;
	}
	
	public void setEdit(BundleProjectConfig edit) {
		this.edit = edit;
	}

}
