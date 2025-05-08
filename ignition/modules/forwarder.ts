/**
 * Utility file for sharing common parameters across modules
 */

/**
 * Get the default zero address for the trusted forwarder
 * @returns Zero address as a string
 */
export const getZeroAddress = (): string => {
	return "0x0000000000000000000000000000000000000000";
};

/**
 * Creates a function to get the trustedForwarder parameter for modules
 * @param m The Ignition module builder
 * @returns The trustedForwarder parameter
 */
export const getTrustedForwarder = <T>(m: {
	getParameter: (name: string, defaultValue: string) => T;
}): T => {
	return m.getParameter("trustedForwarder", getZeroAddress());
};
