import utest.Runner;
import utest.ui.Report;

function main() {
	var runner = new Runner();

	runner.addCases("utests", false);

	var report = Report.create(runner);

	runner.run();

	Sys.println("Tests were successful.");
	Sys.exit(0);
}