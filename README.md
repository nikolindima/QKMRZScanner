[![Swift 4.2](https://img.shields.io/badge/Swift-4.2-orange.svg?style=flat)](https://developer.apple.com/swift/)
[![Git](https://img.shields.io/badge/GitHub-Mattijah-blue.svg?style=flat)](https://github.com/Mattijah)


# QKMRZScanner

Scans MRZ (Machine Readable Zone) from identity documents.

![scanning_preview](ReadmeAssets/scanning.gif)

## MRZ transformation

Version 3.2.0
	- Add correction for NLD passports. Used regex ^[A-NP-Z]{2}[A-NP-Z0-9]{6}[0-9]
Version 3.3.0
	- Add correction for D passports. Used regex ^[CFGHJK]{1}[CFGHJKLMNPRTVWXYZ0-9]{8}$
	- Add correction for IRL passports. Used regex ^[A-Z0-9]{7,9}$

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details
