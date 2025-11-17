A test is not a unit test if:
- It talks to the database
- It communicates across the network
- It touches the file system
- It can't run at the same time as any of your other unit tests
- You have to do special things to your environment (such as editing config files) to run it.

## How To Choose the Next Test To Write
Telling you to simply go and write a failing test "just like that" is kind of unfair. It sounds easy, but how should one go about it?

## TDD Benefits
- all of the code is unit tested
- the code is written to satisfy the tests -- there are no superfluous parts of the code that have been written just because they "could possibly be useful" or "will surely be required one day" (YAGNI)
- writing the smallest amount of code to make the test pass leads to simple solutions (KISS)
- thanks to the refactoring phase the code is clean and readable (DRY)
- it is easy to go back into the coding, even after interruptions; all you have to do is take the next test from the list and start the next cycle.
## Mocks, Stubs, Test Spies
In general, test doubles are used to replace DOCs, where this allows us to :
- gain full control over the environment in which the SUT is running,
- move beyond state testing and verify interactions between the SUT and its DOCs.

## Types of test doubles
| test-double type | also known as | description                                                                            |
| ---------------- | ------------- | -------------------------------------------------------------------------------------- |
| dummy object     | dummy         | needs exist, no real collaboration needed                                              |
| test stub        | stub          | used for passing some values to the SUT ("indirect inputs")                            |
| test spy         | spy           | used verify if the SUT calls specific methods of the collaborator ("indirect outputs") |
| mock object      | mock          |                                                                                        |

![[Pasted image 20231206174906.png]]

Based on this data, we may arrive at the following observations:
- **Dummies** and **stubs** are used to **prepare the environment for testing**. They are not used for verification. A dummy is employed to be passed as a value (e.g. as a parameter of a direct method call), while a stub passes some data to the SUT, substituting for one its DOCs.
- The purpose of test spies and mock is to verify the correctness of the communication between the SUT and DOCs. Yet they differ in how they are used in test code, and that is why they have distinct names. Both can also participate in test-fixture setting; however, this is only their secondary purpose
- No test double is used for direct outputs of the SUT, as it can be tested directly by observing its responses.

