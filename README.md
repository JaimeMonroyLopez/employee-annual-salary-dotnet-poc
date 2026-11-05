# Employee Annual Salary (.NET Framework 4.8 PoC)

![.NET Framework](https://img.shields.io/badge/.NET%20Framework-4.8-512BD4)
![ASP.NET MVC](https://img.shields.io/badge/ASP.NET%20MVC-5.2.7-512BD4)
![Docker](https://img.shields.io/badge/Docker-Windows%20containers-2496ED)

This small web app answers one question: **how much does an employee earn in a year?**

You type an employee ID, or leave the field empty to see everyone. The app gets the employee data and works out the annual salary based on the type of contract each person has.

It started as a hands-on technical test. It is small, so you can read the code in one sitting and see how a classic **layered ASP.NET MVC application** is put together.

## Quick start

You only need **Docker Desktop** on Windows, switched to **Windows containers**. [Section 7](#7-run-it-yourself) explains why.

```powershell
git clone https://github.com/JaimeMonroyLopez/employee-annual-salary-dotnet-poc.git
cd employee-annual-salary-dotnet-poc
.\docker\build-and-run.ps1
```

Open **http://localhost:8080/**, leave the ID empty and press **Get Employees**.

## Contents

1. [The idea in 30 seconds](#1-the-idea-in-30-seconds)
2. [What you see on screen](#2-what-you-see-on-screen)
3. [How the code is organized (the layers)](#3-how-the-code-is-organized-the-layers)
4. [The design pattern inside: Factory](#4-the-design-pattern-inside-factory)
5. [Follow one request from start to end](#5-follow-one-request-from-start-to-end)
6. [Where the data comes from (and why there is a mock)](#6-where-the-data-comes-from-and-why-there-is-a-mock)
7. [Run it yourself](#7-run-it-yourself)
8. [Tech stack](#8-tech-stack)
9. [Project layout](#9-project-layout)
10. [When something goes wrong](#10-when-something-goes-wrong)
11. [Try it yourself: small exercises](#11-try-it-yourself-small-exercises)
12. [Glossary](#12-glossary)

---

## 1. The idea in 30 seconds

Employees have one of two contract types, and each one turns into a yearly amount differently:

| Contract type | How the annual salary is calculated | Example |
|---|---|---|
| `HourlySalaryEmployee` | `120 × hourly salary × 12` (120 hours a month, 12 months) | 60,000 → **86,400,000** |
| `MonthlySalaryEmployee` | `monthly salary × 12` | 80,000 → **960,000** |

The **contract type** decides which rule applies. The interesting part of the code is how the app picks the right rule without a long chain of `if` statements. Section 4 explains how.

---

## 2. What you see on screen

- **Employee Search page**
  - Leave the ID empty (or type `0`) and press **Get Employees**: you get a table with every employee.
  - Type an ID (for example `2`): you get only that employee.
  - Type an ID that does not exist (for example `99`): you get *"Employee ID does not exist."*
  - Type letters: the browser stops you with *"Only numbers > 0"* before anything is sent.
- **Contact page**: who built it.

A blue **Valid data** box at the top tells you which IDs you can try (1, 2, 3, 4).

---

## 3. How the code is organized (the layers)

Think of the app as a stack of floors. Each floor talks **only to the one below it**, so a change on one floor doesn't break the others.

```
┌──────────────────────────────────────────────┐
│ FrontEnd (MVCApp)                            │  What the user sees: pages, form, table
│   HomeController, Razor views                │
└───────────────────────┬──────────────────────┘
                        ▼
┌──────────────────────────────────────────────┐
│ BusinessLayer (BusinessAccess)               │  The rules: "how is the annual salary computed?"
│   BusinessAccessClass, ContractSalaryFactory │
└───────────────────────┬──────────────────────┘
                        ▼
┌──────────────────────────────────────────────┐
│ DataLayer (DataAccess, DataLayerHelperClass) │  Getting the data: calls the employees API
│   HttpClient + JSON → objects                │  and turns the JSON into C# objects
└───────────────────────┬──────────────────────┘
                        ▼
                Employees API (JSON)

Common (used by every floor):
  Entities           → Employee / EmployeeDTO  (the shape of an employee)
  Helpers            → Constants               (contract type names)
  ExceptionHandling  → reserved for shared error handling (empty for now)
```

**Why split it like this?** If tomorrow the employees come from a database instead of an API, you only touch the **DataLayer**. The salary rules and the pages stay exactly the same.

**Why are there two employee classes?** `EmployeeDTO` is the shape of the data as it **travels** between the API and the layers (DTO means *Data Transfer Object*). `Employee` is the shape the **page** works with. Keeping them apart means a change in the API does not force a change in the views. The controller copies one into the other (`TranslateObject`).

---

## 4. The design pattern inside: Factory

Each contract type has its own small class that knows **one** rule:

```
AbstractContractType                 (the common "contract")
├── ContractAnnualHourlySalary       → 120 × salary × 12
└── ContractAnnualMonthlySalary      → salary × 12
```

`ContractSalaryFactory` looks at the employee's `contractTypeName` and **hands back the right class**:

```csharp
switch (employeeDTO.contractTypeName)
{
    case Constants.HourlySalaryEmployee:  return new ContractAnnualHourlySalary();
    case Constants.MonthlySalaryEmployee: return new ContractAnnualMonthlySalary();
}
```

The business layer never asks "what kind of contract is this?" more than once. It asks the factory for the calculator and uses it. To add a new contract type (say, a commission contract), you add **one new class** and **one new `case`**. Nothing else changes.

---

## 5. Follow one request from start to end

Here is what happens when you type `2` and press the button:

1. The **browser** checks that `2` is a number and posts the form to `/Home/GetEmployee`.
2. **`HomeController`** receives the ID and asks the business layer for that employee.
3. **`BusinessAccessClass`** asks the data layer for the employee list.
4. **`DataAccessClass`** calls the employees API with `HttpClient` and gets back JSON.
5. **`DataLayerHelperClass`** turns that JSON into `EmployeeDTO` objects (Newtonsoft.Json).
6. Back in the **business layer**, the **factory** picks the calculator for employee 2's contract and fills in the annual salary.
7. The **controller** puts the result in the view, and **Razor** draws the table.

---

## 6. Where the data comes from (and why there is a mock)

The original exercise used an external employees API from a company we call **FakeCompany** here. That API is **not online any more**, so the app would have nothing to show.

To keep the app working without changing how it behaves, it reads the same kind of JSON from a **mock file** that the site serves itself:

- [`FrontEnd/mock/employees.json`](FrontEnd/mock/employees.json): 4 sample employees, 2 hourly and 2 monthly.

The data layer still makes a real HTTP call. It just points somewhere else. The address lives in **configuration**, not in the code:

```xml
<!-- FrontEnd/Web.config → <appSettings> -->
<add key="CompanyName"     value="FakeCompany" />
<add key="EmployeesApiUrl" value="http://localhost/mock/employees.json" />
```

- **`EmployeesApiUrl`**: change it to a real API and the app uses that instead. No code changes, no recompiling of the logic.
- **`CompanyName`**: the company name shown on the page, kept in one place.

---

## 7. Run it yourself

The app is ASP.NET MVC 5 on **.NET Framework 4.8**, so it runs on **IIS** (Windows), not on Kestrel or Linux.

### What you need depends on what you want to do

| You want to… | Install on your machine |
|---|---|
| **Just run it** | **Docker Desktop** in Windows containers mode. Nothing else. |
| **Change the code and see the result** | Still only Docker. Edit the files with any editor and rebuild: the code is compiled **inside** Docker. |
| **Full IDE experience** (IntelliSense, live errors, step-by-step debugging) | Visual Studio, or Visual Studio Build Tools with *Web development build tools* and the *.NET Framework 4.8 targeting pack* |

### Option A: Docker (recommended, nothing else to install)

**1. Switch Docker Desktop to Windows containers:** right-click the whale icon → *Switch to Windows containers…*

**2. Build and start it.** Run one of these from the repository root:

```powershell
.\docker\build-and-run.ps1                               # shortcut: checks Docker, then runs compose
docker compose -f docker/docker-compose.yml up -d --build  # the same thing, by hand
```

**3. Open http://localhost:8080/**

To stop it:

```powershell
docker compose -f docker/docker-compose.yml down
```

The first build downloads two Microsoft base images (the SDK to compile and the IIS image to run), several GB in total. Docker caches them, so later builds are much faster.

#### What happens when you run the script

`build-and-run.ps1` is the **one button**: you don't need to know the other files to use it. This is what it sets in motion:

```
.\docker\build-and-run.ps1
   │  1. Is Docker running?             → if not: "Start Docker Desktop"
   │  2. Is it in Windows containers?   → if not: "Switch to Windows containers..."
   ▼
docker compose up --build              (the script calls it)
   │  reads docker-compose.yml: "build with docker/Dockerfile,
   │  context = repository root, port 8080 → 80, name salary-mvc"
   ▼
Docker builds the image
   │  • applies .dockerignore on its own (nobody calls it: Docker always
   │    looks for it in the build context and leaves bin/, obj/, .git/... out)
   │  • follows the Dockerfile: stage 1 compiles, stage 2 puts the site on IIS
   ▼
compose starts the container  →  http://localhost:8080/
```

#### The Docker files, one by one

| File | Answers the question | Required? |
|---|---|---|
| [`docker/Dockerfile`](docker/Dockerfile) | **What is inside the image and how is it built?** | Yes |
| [`docker/docker-compose.yml`](docker/docker-compose.yml) | **How is the container started?** Port, container name… | No, but it saves you long commands |
| [`docker/build-and-run.ps1`](docker/build-and-run.ps1) | **Is Docker ready?** Then it runs compose for you | No, it is a shortcut |
| [`.dockerignore`](.dockerignore) | **What should Docker NOT copy** when building? `bin/`, `obj/`, `.git/`… | No, but it keeps builds fast and clean |

The **Dockerfile** is the recipe. The **image** is the dish Docker cooks from it and keeps in its own storage: it is not a file in this repository. The **container** is that dish served, the image running. Only the recipe is committed, and every machine cooks its own image.

#### Multi-stage build: compile in one stage, run in another

The Dockerfile has **two stages**. Each `FROM` starts a new one:

```dockerfile
FROM mcr.microsoft.com/dotnet/framework/sdk:4.8-...    AS build   # stage 1: MSBuild compiles and publishes
...
FROM mcr.microsoft.com/dotnet/framework/aspnet:4.8-...            # stage 2: IIS runs the site
COPY --from=build C:/publish .                                    # only the result crosses over
```

- **Stage 1 (`build`)** has every tool needed to compile, so your machine does not need them.
- **Stage 2** takes **only the published site** from stage 1. The final image has no SDK, no source code and no temporary files, so it is smaller and safer.

### Option B: Visual Studio and IIS Express

1. Open `SalaryAmounts.sln`.
2. In `FrontEnd/Web.config`, set `EmployeesApiUrl` to `http://localhost:57835/mock/employees.json`.
3. Run **MVCApp**. It opens on `http://localhost:57835/`.

### Only compile

```powershell
& "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\MSBuild\Current\Bin\MSBuild.exe" SalaryAmounts.sln /t:Rebuild
```

Use **MSBuild**, not `dotnet build`. The `dotnet` tool is made for modern .NET and does not know how to build classic ASP.NET web projects.

---

## 8. Tech stack

| Piece | Version | What it is used for |
|---|---|---|
| .NET Framework | 4.8 | Runtime |
| ASP.NET MVC / Razor | 5.2.7 / 3.2.7 | Web pages and controllers |
| Microsoft.AspNet.WebApi.Client | 5.2.7 | HTTP helpers for the API call |
| Newtonsoft.Json | 13.0.4 | JSON ↔ C# objects |
| jQuery / jQuery Validation | 3.7.1 / 1.21.0 | Browser-side checks |
| Bootstrap | 3.4.1 | Layout and styles |
| Docker images | `mcr.microsoft.com/dotnet/framework/sdk:4.8` / `aspnet:4.8` | Compile / run on IIS, in Windows containers |

**The NuGet packages are committed in `packages/` on purpose.** Packages can disappear from the internet over time. With the packages inside the repository, a clone builds, runs and can be debugged years from now, even offline, both in Docker and in Visual Studio. The solution also brings its own [`nuget.config`](nuget.config), so restoring or updating packages does not depend on how NuGet is set up on your machine.

---

## 9. Project layout

```
SalaryAmounts.sln
├─ FrontEnd/          MVCApp: controllers, views, scripts, mock/employees.json
├─ BusinessLayer/     BusinessAccess: salary rules + factory
├─ DataLayer/
│   ├─ DataAccess/            calls the employees API
│   └─ DataLayerHelperClass/  JSON → objects
├─ Common/
│   ├─ Entities/              Employee, EmployeeDTO
│   ├─ Helpers/               Constants
│   └─ ExceptionHandling/     (empty for now)
├─ docker/            Dockerfile, docker-compose.yml, build-and-run.ps1
├─ packages/          NuGet packages
├─ .dockerignore      what Docker leaves out of the build
└─ nuget.config       NuGet sources for this solution
```

---

## 10. When something goes wrong

| What you see | Why it happens | What to do |
|---|---|---|
| `Docker is not running` | Docker Desktop is closed | Open Docker Desktop and wait until it says *Engine running* |
| `Docker is in 'linux' mode` | Docker runs Linux containers by default, and this app needs Windows | Whale icon → *Switch to Windows containers…*. Your Linux containers are kept; switch back when you are done |
| The *Switch to Windows containers…* option is **missing** | The Windows **Containers** feature is off, or Docker Desktop was installed with `--no-windows-containers` | Turn the feature on (admin PowerShell: `Enable-WindowsOptionalFeature -Online -FeatureName Containers -All`, then restart). If it is still missing, run the Docker Desktop installer again **without** that flag |
| `port is already allocated` | Something else uses port 8080 | Use another port: `.\docker\build-and-run.ps1 -Port 9090` |
| The first build takes a long time | It is downloading the Microsoft base images (several GB) | Only the first time. Later builds reuse them |
| You changed the code but the page did not change | The image was not rebuilt | Run the script again: `--build` compiles your changes inside Docker |

---

## 11. Try it yourself: small exercises

Each exercise is small and shows one idea from this README. After each change, run `.\docker\build-and-run.ps1` again and check the page.

1. **Add an employee** (data): add a 5th employee to [`FrontEnd/mock/employees.json`](FrontEnd/mock/employees.json) and search for ID `5`. *You changed the data without touching any code.*
2. **Change the port** (configuration): run `.\docker\build-and-run.ps1 -Port 9090` and open `http://localhost:9090/`. *Same image, different way of starting it: that's compose's job.*
3. **Add a contract type** (Factory pattern): create a `ContractAnnualCommissionSalary` class, add a constant in `Helpers/Constants.cs` and one more `case` in `ContractSalaryFactory`. *Notice how little else needs to change.*
4. **Point to another API** (layers): change `EmployeesApiUrl` in `Web.config` to any URL that returns the same JSON shape. *Only the data source changes. The rules and the pages don't.*

---

## 12. Glossary

| Term | In plain words |
|---|---|
| **ASP.NET MVC** | Microsoft's framework for web apps split into **M**odel (data), **V**iew (page) and **C**ontroller (handles the request) |
| **Razor** | The syntax that mixes HTML and C# in the `.cshtml` views |
| **IIS** | Internet Information Services, the Windows web server that runs classic ASP.NET apps |
| **DTO** | *Data Transfer Object*: a simple class that only carries data between layers |
| **Factory pattern** | A class whose job is to **create the right object** for each case, so the rest of the code doesn't need to know which one |
| **Mock** | A fake but realistic stand-in for something real, here the employees API |
| **NuGet / packages.config** | .NET's package manager, and the file where each classic project lists its packages |
| **Docker image** | A packaged, ready-to-run snapshot (OS + IIS + app). Docker stores it internally; it is not a file in the repo |
| **Container** | An image that is running |
| **Dockerfile** | The recipe Docker follows to build the image |
| **Multi-stage build** | A Dockerfile with several `FROM` stages: one compiles, the last one only runs the result |
| **Docker Compose** | A YAML file that says how to start containers: ports, names, services |
| **Build context** | The folder Docker receives to build the image (here, the repository root, minus what `.dockerignore` excludes) |
| **Windows containers** | Containers that run Windows instead of Linux. Needed because .NET Framework and IIS only run on Windows |

---

## Author

**Jaime Monroy**, Senior Full Stack Developer | Data Analyst
🌐 [jaimemonroy.dev](https://jaimemonroy.dev)
