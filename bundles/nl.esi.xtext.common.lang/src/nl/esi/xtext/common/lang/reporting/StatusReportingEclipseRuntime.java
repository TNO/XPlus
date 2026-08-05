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

import org.eclipse.core.runtime.IStatus;
import org.eclipse.core.runtime.Plugin;
import org.eclipse.emf.common.util.Logger;

import com.google.inject.Inject;

/**
 * An interface for reporting status messages, allowing implementations to
 * handle the reporting of validation messages.
 */
public class StatusReportingEclipseRuntime implements IStatusReporting {
	
	private final Logger logger;
	private final String pluginId;
	
	private boolean skipOkStatus = true;
	
	@Inject
    public StatusReportingEclipseRuntime(Plugin plugin) {
		if( plugin instanceof Logger logger) {
			this.logger = logger;
			this.pluginId = plugin.getBundle().getSymbolicName();
		}
		else {
			throw new IllegalArgumentException("Plugin must implement Logger interface");
		}
	}
	/**
	 * Reports a status message.
	 *
	 * @param report the status report to be reported
	 */
	@Override
	public void addReport(IStatus report) {
		if (skipOkStatus && report.getSeverity() == IStatus.OK) {
			return; // Skip reporting OK status messages
		}
		if(report instanceof StatusReport statusReport) {
			// If the report is a StatusReport, set the plugin ID
			statusReport.setPluginId(pluginId);
		}
		// Using the standard eclipse logger to log the status
		this.logger.log(report);
	}
	
	/**
	 * Reports an exception as a status message.
	 *
	 * @param exception the status report to be reported
	 */
	@Override
	public void addReport(Exception exception) {
		this.logger.log(exception);
	}

}