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

/**
 * An interface for reporting status messages, allowing implementations to
 * handle the reporting of validation messages.
 */
public interface IStatusReporting {
	/**
	 * Reports a status message.
	 *
	 * @param report the status report to be reported
	 */
	void addReport(IStatus report);
	/**
	 * Reports an exception message.
	 *
	 * @param report the status report to be reported
	 */
	void addReport(Exception report);

}