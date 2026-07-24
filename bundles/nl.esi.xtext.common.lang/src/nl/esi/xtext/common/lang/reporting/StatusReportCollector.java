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

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import org.eclipse.core.runtime.IStatus;

import com.google.inject.Singleton;

/**
 * An general class for reporting status messages, allowing implementations to
 * handle the reporting of status messages.
 */
@Singleton
public class StatusReportCollector implements IStatusReporting {
	private final List<StatusReport> reports = Collections.synchronizedList(new ArrayList<>());
	/**
	 * Reports a status message.
	 * Supports reporting of StatusReport, IStatus, and Exception objects. Other object types will be logged as unsupported.
	 *
	 * @param object the status report to be reported
	 */
	@Override
	public void addReport(IStatus report) {
		if (report == null) {
			return;
		}
		if( report instanceof StatusReport statusReport) {
			reports.add(statusReport);
		} else if( report instanceof IStatus) {
			reports.add(StatusReportHelper.fromIStatus(report));
		}
	}

	@Override
	public void addReport(Exception report) {
		addReport(StatusReportHelper.fromException(report, null, null));
	}

	public List<StatusReport> getReports() {
		return Collections.unmodifiableList(reports);
	}
}