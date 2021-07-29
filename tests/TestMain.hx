package tests;

import utest.Runner;
import utest.ui.Report;

function main() {
	var runner = new Runner();

	runner.addCases("tests.utest");

	Report.create(runner);

	runner.run();

	Sys.println("Tests were successful.");
}