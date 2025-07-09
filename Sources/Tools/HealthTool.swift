//
//  HealthTool.swift
//  FoundationLab
//
//  Created by Rudrank Riyam on 6/17/25.
//

import Foundation
import FoundationModels
import HealthKit

/// `HealthTool` provides access to HealthKit data.
///
/// This tool can read, write, and analyze health data from the Health app.
/// Important: This requires HealthKit entitlements and user permission.
public struct HealthTool: Tool {

  /// The name of the tool, used for identification.
  public let name = "accessHealth"
  /// A brief description of the tool's functionality.
  public let description =
    "Access and analyze health data including steps, heart rate, workouts, and more"

  /// Arguments for health data operations.
  @Generable
  public struct Arguments {
    /// The action to perform: "read", "write", "summary", "trends"
    @Guide(description: "The action to perform: 'read', 'write', 'summary', 'trends'")
    public var action: String

    /// Type of health data: "steps", "heartRate", "weight", "height", "bloodPressure", "workouts", etc.
    @Guide(
      description:
        "Type of health data: 'steps', 'heartRate', 'weight', 'height', 'bloodPressure', 'workouts', etc."
    )
    public var dataType: String?

    /// Start date for data query (YYYY-MM-DD format)
    @Guide(description: "Start date for data query (YYYY-MM-DD format)")
    public var startDate: String?

    /// End date for data query (YYYY-MM-DD format)
    @Guide(description: "End date for data query (YYYY-MM-DD format)")
    public var endDate: String?

    /// Value to write (for write action)
    @Guide(description: "Value to write (for write action)")
    public var value: Double?

    /// Unit for the health data (e.g., "count", "kg", "bpm")
    @Guide(description: "Unit for the health data (e.g., 'count', 'kg', 'bpm')")
    public var unit: String?

    /// Time period for trends: "day", "week", "month", "year"
    @Guide(description: "Time period for trends: 'day', 'week', 'month', 'year'")
    public var period: String?

    public init(
      action: String = "",
      dataType: String? = nil,
      startDate: String? = nil,
      endDate: String? = nil,
      value: Double? = nil,
      unit: String? = nil,
      period: String? = nil
    ) {
      self.action = action
      self.dataType = dataType
      self.startDate = startDate
      self.endDate = endDate
      self.value = value
      self.unit = unit
      self.period = period
    }
  }

  private let healthStore = HKHealthStore()

  public init() {}

  public func call(arguments: Arguments) async throws -> ToolOutput {
    // Check if HealthKit is available
    guard HKHealthStore.isHealthDataAvailable() else {
      return createErrorOutput(error: HealthError.healthKitNotAvailable)
    }

    guard let dataType = arguments.dataType else {
      return createErrorOutput(error: HealthError.missingDataType)
    }

    switch dataType.lowercased() {
    case "steps":
      return await querySteps(arguments: arguments)
    case "heartrate":
      return await queryHeartRate(arguments: arguments)
    case "workouts":
      return await queryWorkouts(arguments: arguments)
    case "sleep":
      return await querySleep(arguments: arguments)
    case "activeenergy":
      return await queryActiveEnergy(arguments: arguments)
    case "distance":
      return await queryDistance(arguments: arguments)
    default:
      return createErrorOutput(error: HealthError.invalidDataType)
    }
  }

  private func querySteps(arguments: Arguments) async -> ToolOutput {
    guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
      return createErrorOutput(error: HealthError.dataTypeNotAvailable)
    }

    // Request authorization
    do {
      try await healthStore.requestAuthorization(toShare: [], read: [stepType])
    } catch {
      return createErrorOutput(error: HealthError.authorizationDenied)
    }

    let (startDate, endDate) = getDateRange(arguments: arguments)
    let datePredicate = HKQuery.predicateForSamples(
      withStart: startDate, end: endDate, options: .strictStartDate)
    let samplePredicate = HKSamplePredicate.quantitySample(type: stepType, predicate: datePredicate)

    let descriptor = HKStatisticsQueryDescriptor(
      predicate: samplePredicate,
      options: .cumulativeSum
    )

    do {
      let result = try await descriptor.result(for: healthStore)
      guard let sum = result?.sumQuantity() else {
        return createErrorOutput(error: HealthError.noData)
      }

      let steps = sum.doubleValue(for: HKUnit.count())
      let dateFormatter = DateFormatter()
      dateFormatter.dateStyle = .medium

      return ToolOutput(
        GeneratedContent(properties: [
          "status": "success",
          "dataType": "steps",
          "totalSteps": Int(steps),
          "startDate": dateFormatter.string(from: startDate),
          "endDate": dateFormatter.string(from: endDate),
          "dailyAverage": Int(steps / Double(self.daysBetween(start: startDate, end: endDate))),
          "message": "Total steps: \(Int(steps))",
        ])
      )
    } catch {
      return createErrorOutput(error: error)
    }
  }

  private func queryHeartRate(arguments: Arguments) async -> ToolOutput {
    guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
      return createErrorOutput(error: HealthError.dataTypeNotAvailable)
    }

    // Request authorization
    do {
      try await healthStore.requestAuthorization(toShare: [], read: [heartRateType])
    } catch {
      return createErrorOutput(error: HealthError.authorizationDenied)
    }

    let (startDate, endDate) = getDateRange(arguments: arguments)
    let datePredicate = HKQuery.predicateForSamples(
      withStart: startDate, end: endDate, options: .strictStartDate)
    let samplePredicate = HKSamplePredicate.quantitySample(
      type: heartRateType, predicate: datePredicate)

    let descriptor = HKSampleQueryDescriptor(
      predicates: [samplePredicate],
      sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
      limit: 100
    )

    do {
      let samples = try await descriptor.result(for: healthStore)
      guard !samples.isEmpty else {
        return createErrorOutput(error: HealthError.noData)
      }

      var heartRates: [Double] = []
      var latestReading = ""

      for (index, sample) in samples.enumerated() {
        let heartRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
        heartRates.append(heartRate)

        if index == 0 {
          let dateFormatter = DateFormatter()
          dateFormatter.dateStyle = .medium
          dateFormatter.timeStyle = .short
          latestReading = "\(Int(heartRate)) bpm at \(dateFormatter.string(from: sample.startDate))"
        }
      }

      let average = heartRates.reduce(0, +) / Double(heartRates.count)
      let min = heartRates.min() ?? 0
      let max = heartRates.max() ?? 0

      return ToolOutput(
        GeneratedContent(properties: [
          "status": "success",
          "dataType": "heartRate",
          "latestReading": latestReading,
          "averageBPM": Int(average),
          "minBPM": Int(min),
          "maxBPM": Int(max),
          "sampleCount": heartRates.count,
          "message": "Average heart rate: \(Int(average)) bpm",
        ])
      )
    } catch {
      return createErrorOutput(error: error)
    }
  }

  private func queryWorkouts(arguments: Arguments) async -> ToolOutput {
    let workoutType = HKObjectType.workoutType()

    // Request authorization
    do {
      try await healthStore.requestAuthorization(toShare: [], read: [workoutType])
    } catch {
      return createErrorOutput(error: HealthError.authorizationDenied)
    }

    let (startDate, endDate) = getDateRange(arguments: arguments)
    let datePredicate = HKQuery.predicateForSamples(
      withStart: startDate, end: endDate, options: .strictStartDate)
    let samplePredicate = HKSamplePredicate.workout(datePredicate)

    let descriptor = HKSampleQueryDescriptor(
      predicates: [samplePredicate],
      sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
      limit: 20
    )

    do {
      let workouts = try await descriptor.result(for: healthStore)
      guard !workouts.isEmpty else {
        return createErrorOutput(error: HealthError.noData)
      }

      var workoutDescription = ""
      var totalDuration: TimeInterval = 0
      var totalCalories: Double = 0

      let dateFormatter = DateFormatter()
      dateFormatter.dateStyle = .medium
      dateFormatter.timeStyle = .short

      // Process workouts
      for (index, workout) in workouts.enumerated() {
        let duration = workout.duration / 60  // Convert to minutes
        let distance = workout.totalDistance?.doubleValue(for: .meter()) ?? 0

        totalDuration += workout.duration

        // Fetch active energy burned for this workout using async/await
        let calories = await self.fetchActiveEnergyForWorkout(workout)
        totalCalories += calories

        workoutDescription +=
          "\(index + 1). \(self.workoutActivityName(workout.workoutActivityType))\n"
        workoutDescription += "   Date: \(dateFormatter.string(from: workout.startDate))\n"
        workoutDescription += "   Duration: \(Int(duration)) minutes\n"
        if calories > 0 {
          workoutDescription += "   Calories: \(Int(calories))\n"
        }
        if distance > 0 {
          workoutDescription += "   Distance: \(String(format: "%.2f", distance / 1000)) km\n"
        }
        workoutDescription += "\n"
      }

      return ToolOutput(
        GeneratedContent(properties: [
          "status": "success",
          "dataType": "workouts",
          "workoutCount": workouts.count,
          "totalDurationMinutes": Int(totalDuration / 60),
          "totalCalories": Int(totalCalories),
          "workouts": workoutDescription.trimmingCharacters(in: .whitespacesAndNewlines),
          "message": "Found \(workouts.count) workout(s)",
        ])
      )
    } catch {
      return createErrorOutput(error: error)
    }
  }

  private func fetchActiveEnergyForWorkout(_ workout: HKWorkout) async -> Double {
    guard let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
      return 0
    }

    // Use the new async API for iOS 26/macOS 26
    let datePredicate = HKQuery.predicateForSamples(
      withStart: workout.startDate,
      end: workout.endDate,
      options: .strictStartDate
    )
    let samplePredicate = HKSamplePredicate.quantitySample(
      type: energyType,
      predicate: datePredicate
    )

    let descriptor = HKStatisticsQueryDescriptor(
      predicate: samplePredicate,
      options: .cumulativeSum
    )

    do {
      let statistics = try await descriptor.result(for: healthStore)
      return statistics?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
    } catch {
      return 0
    }
  }

  private func querySleep(arguments: Arguments) async -> ToolOutput {
    guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
      return createErrorOutput(error: HealthError.dataTypeNotAvailable)
    }

    // Request authorization
    do {
      try await healthStore.requestAuthorization(toShare: [], read: [sleepType])
    } catch {
      return createErrorOutput(error: HealthError.authorizationDenied)
    }

    let (startDate, endDate) = getDateRange(arguments: arguments)
    let datePredicate = HKQuery.predicateForSamples(
      withStart: startDate, end: endDate, options: .strictStartDate)
    let samplePredicate = HKSamplePredicate.categorySample(
      type: sleepType, predicate: datePredicate)

    let descriptor = HKSampleQueryDescriptor(
      predicates: [samplePredicate],
      sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
    )

    do {
      let sleepSamples = try await descriptor.result(for: healthStore)
      guard !sleepSamples.isEmpty else {
        return createErrorOutput(error: HealthError.noData)
      }

      var totalSleepTime: TimeInterval = 0
      var sleepDescription = ""
      let dateFormatter = DateFormatter()
      dateFormatter.dateStyle = .medium

      // Group sleep samples by day
      var sleepByDay: [Date: TimeInterval] = [:]

      for sample in sleepSamples {
        let duration = sample.endDate.timeIntervalSince(sample.startDate)
        totalSleepTime += duration

        let calendar = Calendar.current
        let day = calendar.startOfDay(for: sample.startDate)
        sleepByDay[day, default: 0] += duration
      }

      for (day, duration) in sleepByDay.sorted(by: { $0.key > $1.key }).prefix(7) {
        let hours = duration / 3600
        sleepDescription +=
          "\(dateFormatter.string(from: day)): \(String(format: "%.1f", hours)) hours\n"
      }

      let avgSleepHours = (totalSleepTime / Double(sleepByDay.count)) / 3600

      return ToolOutput(
        GeneratedContent(properties: [
          "status": "success",
          "dataType": "sleep",
          "averageSleepHours": String(format: "%.1f", avgSleepHours),
          "totalNights": sleepByDay.count,
          "sleepData": sleepDescription.trimmingCharacters(in: .whitespacesAndNewlines),
          "message": "Average sleep: \(String(format: "%.1f", avgSleepHours)) hours per night",
        ])
      )
    } catch {
      return createErrorOutput(error: error)
    }
  }

  private func queryActiveEnergy(arguments: Arguments) async -> ToolOutput {
    guard let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
      return createErrorOutput(error: HealthError.dataTypeNotAvailable)
    }

    // Request authorization
    do {
      try await healthStore.requestAuthorization(toShare: [], read: [energyType])
    } catch {
      return createErrorOutput(error: HealthError.authorizationDenied)
    }

    let (startDate, endDate) = getDateRange(arguments: arguments)
    let datePredicate = HKQuery.predicateForSamples(
      withStart: startDate, end: endDate, options: .strictStartDate)
    let samplePredicate = HKSamplePredicate.quantitySample(
      type: energyType, predicate: datePredicate)

    let descriptor = HKStatisticsQueryDescriptor(
      predicate: samplePredicate,
      options: .cumulativeSum
    )

    do {
      let result = try await descriptor.result(for: healthStore)
      guard let sum = result?.sumQuantity() else {
        return createErrorOutput(error: HealthError.noData)
      }

      let calories = sum.doubleValue(for: .kilocalorie())
      let days = daysBetween(start: startDate, end: endDate)
      let dailyAverage = calories / Double(days)

      return ToolOutput(
        GeneratedContent(properties: [
          "status": "success",
          "dataType": "activeEnergy",
          "totalCalories": Int(calories),
          "dailyAverage": Int(dailyAverage),
          "startDate": formatDate(startDate),
          "endDate": formatDate(endDate),
          "message": "Total active energy: \(Int(calories)) calories",
        ])
      )
    } catch {
      return createErrorOutput(error: error)
    }
  }

  private func queryDistance(arguments: Arguments) async -> ToolOutput {
    guard let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
    else {
      return createErrorOutput(error: HealthError.dataTypeNotAvailable)
    }

    // Request authorization
    do {
      try await healthStore.requestAuthorization(toShare: [], read: [distanceType])
    } catch {
      return createErrorOutput(error: HealthError.authorizationDenied)
    }

    let (startDate, endDate) = getDateRange(arguments: arguments)
    let datePredicate = HKQuery.predicateForSamples(
      withStart: startDate, end: endDate, options: .strictStartDate)
    let samplePredicate = HKSamplePredicate.quantitySample(
      type: distanceType, predicate: datePredicate)

    let descriptor = HKStatisticsQueryDescriptor(
      predicate: samplePredicate,
      options: .cumulativeSum
    )

    do {
      let result = try await descriptor.result(for: healthStore)
      guard let sum = result?.sumQuantity() else {
        return createErrorOutput(error: HealthError.noData)
      }

      let meters = sum.doubleValue(for: .meter())
      let kilometers = meters / 1000
      let miles = meters / 1609.344
      let days = daysBetween(start: startDate, end: endDate)
      let dailyAverage = kilometers / Double(days)

      return ToolOutput(
        GeneratedContent(properties: [
          "status": "success",
          "dataType": "distance",
          "totalKilometers": String(format: "%.2f", kilometers),
          "totalMiles": String(format: "%.2f", miles),
          "dailyAverageKm": String(format: "%.2f", dailyAverage),
          "startDate": formatDate(startDate),
          "endDate": formatDate(endDate),
          "message": "Total distance: \(String(format: "%.2f", kilometers)) km",
        ])
      )
    } catch {
      return createErrorOutput(error: error)
    }
  }

  private func getDateRange(arguments: Arguments) -> (Date, Date) {
    let calendar = Calendar.current
    let endDate = Date()

    if let startDateString = arguments.startDate,
      let parsedStartDate = parseDate(startDateString)
    {
      let parsedEndDate = arguments.endDate.flatMap { parseDate($0) } ?? endDate
      return (parsedStartDate, parsedEndDate)
    }

    // Default to 7 days back if no dates provided
    let daysBack = 7
    let startDate = calendar.date(byAdding: .day, value: -daysBack, to: endDate) ?? endDate
    return (startDate, endDate)
  }

  private func parseDate(_ dateString: String) -> Date? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone.current
    return formatter.date(from: dateString)
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter.string(from: date)
  }

  private func daysBetween(start: Date, end: Date) -> Int {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.day], from: start, to: end)
    return max(1, components.day ?? 1)
  }

  private func workoutActivityName(_ type: HKWorkoutActivityType) -> String {
    switch type {
    case .running: return "Running"
    case .walking: return "Walking"
    case .cycling: return "Cycling"
    case .swimming: return "Swimming"
    case .yoga: return "Yoga"
    case .functionalStrengthTraining: return "Strength Training"
    case .traditionalStrengthTraining: return "Weight Training"
    case .coreTraining: return "Core Training"
    case .elliptical: return "Elliptical"
    case .rowing: return "Rowing"
    case .stairClimbing: return "Stair Climbing"
    case .hiking: return "Hiking"
    case .dance: return "Dance"
    case .pilates: return "Pilates"
    default: return "Other Workout"
    }
  }

  private func createErrorOutput(error: Error) -> ToolOutput {
    return ToolOutput(
      GeneratedContent(properties: [
        "status": "error",
        "error": error.localizedDescription,
        "message": "Failed to access health data",
      ])
    )
  }
}

enum HealthError: Error, LocalizedError {
  case healthKitNotAvailable
  case authorizationDenied
  case invalidDataType
  case missingDataType
  case invalidAction
  case dataTypeNotAvailable
  case noData

  var errorDescription: String? {
    switch self {
    case .healthKitNotAvailable:
      return "HealthKit is not available on this device."
    case .authorizationDenied:
      return "Access to health data denied. Please grant permission in Settings."
    case .invalidDataType:
      return
        "Invalid data type. Use 'steps', 'heartRate', 'workouts', 'sleep', 'activeEnergy', or 'distance'."
    case .missingDataType:
      return "Data type is required for this action."
    case .invalidAction:
      return "Invalid action. Use 'read', 'write', 'summary', or 'trends'."
    case .dataTypeNotAvailable:
      return "This health data type is not available."
    case .noData:
      return "No health data found for the specified period."
    }
  }
}
