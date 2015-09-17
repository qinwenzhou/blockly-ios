/*
* Copyright 2015 Google Inc. All Rights Reserved.
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

import Foundation

// MARK: -

/**
Stores information on how to render and position a `Block` on-screen.
*/
@objc(BKYBlockLayout)
public class BlockLayout: Layout {
  // MARK: - Static Properties

  /// The shared instance used to configure all instances of `BlockLayout`.
  public static let sharedConfig = Config()

  // MARK: - Properties

  /// The `Block` to layout.
  public let block: Block

  /// The information for rendering the background for this block.
  public let background = BlockLayout.Background()

  /// The corresponding layout objects for `self.block.inputs[]`
  public private(set) var inputLayouts = [InputLayout]()

  /// A list of all `FieldLayout` objects belonging under this `BlockLayout`.
  public var fieldLayouts: [FieldLayout] {
    var fieldLayouts = [FieldLayout]()
    for inputLayout in inputLayouts {
      fieldLayouts += inputLayout.fieldLayouts
    }
    return fieldLayouts
  }

  /// Z-position of the block layout. Those with higher values should render on top of those with
  /// lower values.
  public var zPosition: CGFloat = 0 {
    didSet {
      if zPosition != oldValue {
        self.delegate?.layoutDidChange(self)
      }
    }
  }

  /// Whether this block is the first child of its parent, which must be a `BlockGroupLayout`.
  public var topBlockInBlockLayout: Bool {
    return parentBlockGroupLayout.blockLayouts[0] == self ?? false
  }

  /// The parent block group layout
  public var parentBlockGroupLayout: BlockGroupLayout {
    return parentLayout as! BlockGroupLayout
  }

  // MARK: - Initializers

  public required init(
    block: Block, workspaceLayout: WorkspaceLayout!, parentLayout: BlockGroupLayout) {
      self.block = block
      super.init(workspaceLayout: workspaceLayout, parentLayout: parentLayout)
      self.block.delegate = self
  }

  // MARK: - Super

  public override var childLayouts: [Layout] {
    return inputLayouts
  }

  public override func layoutChildren() {
    // TODO:(vicng) Add x/y padding everywhere

    var xOffset: CGFloat = 0
    var yOffset: CGFloat = 0
    var minimalWidthRequired: CGFloat = 0
    var currentLineHeight: CGFloat = 0
    var previousInputLayout: InputLayout?
    var backgroundRow: BackgroundRow!

    // Set the background properties based on the block layout and remove all rows from the
    // background
    self.background.updateRenderPropertiesFromBlockLayout(self)
    self.background.removeAllRows()

    // Update relative position/size of inputs
    for inputLayout in inputLayouts {
      if backgroundRow == nil || // First row
        !block.inputsInline || // External inputs
        previousInputLayout?.input.type == .Statement || // Previous input was a statement
        inputLayout.input.type == .Statement // Current input is a statement
      {
        // Start a new row
        backgroundRow = BackgroundRow()
        background.appendRow(backgroundRow)

        // Reset values for this row
        xOffset =
          (self.background.maleOutputConnector ? BlockLayout.sharedConfig.puzzleTabWidth : 0)
        yOffset += currentLineHeight
        currentLineHeight = 0
      }

      // Append this input layout to the current row
      backgroundRow.inputLayouts.append(inputLayout)

      // Perform layout
      inputLayout.layoutChildren()
      inputLayout.relativePosition.x = xOffset
      inputLayout.relativePosition.y = yOffset

      // Update the maximum field width used
      if !block.inputsInline {
        minimalWidthRequired =
          max(minimalWidthRequired, inputLayout.minimalFieldWidthRequired)
      } else if inputLayout.input.type == .Statement {
        minimalWidthRequired =
          max(minimalWidthRequired, inputLayout.minimalStatementWidthRequired)
      }

      // Update position coordinates for this row
      xOffset += inputLayout.size.width
      currentLineHeight = max(currentLineHeight, inputLayout.size.height)
      previousInputLayout = inputLayout
    }

    // Increase the amount of space used for statements and external inputs, re-layout each
    // background row based on a new maximum width, and calculate the size needed for this entire
    // BlockLayout.
    var size = WorkspaceSizeZero

    for backgroundRow in self.background.rows {
      if inputLayouts.isEmpty {
        continue
      }

      let lastInputLayout = backgroundRow.inputLayouts.last!
      if lastInputLayout.input.type == .Statement {
        // Maximize the amount of space for a statement
        lastInputLayout.maximizeStatementWidthTo(minimalWidthRequired)
      } else if !block.inputsInline {
        // Maximize the amount of space for fields
        lastInputLayout.maximizeFieldWidthTo(minimalWidthRequired)
      }

      // Update the background row based on the new max width
      backgroundRow.updateRenderPropertiesWithMaximumRowWidth(minimalWidthRequired)

      size = LayoutHelper.sizeThatFitsLayout(
        backgroundRow.inputLayouts.last!, fromInitialSize: size)
    }

    // Update the size required for this block
    self.size = size
  }

  // MARK: - Public

  /**
  Appends an inputLayout to `self.inputLayouts` and sets its `parentLayout` to this instance.

  - Parameter inputLayout: The `InputLayout` to append.
  */
  public func appendInputLayout(inputLayout: InputLayout) {
    inputLayout.parentLayout = self
    inputLayouts.append(inputLayout)
  }

  /**
  Removes `self.inputLayouts[index]`, sets its `parentLayout` to nil, and returns it.

  - Parameter index: The index to remove from `inputLayouts`.
  - Returns: The `BlockLayout` that was removed.
  */
  public func removeInputLayoutAtIndex(index: Int) -> InputLayout {
    let inputLayout = inputLayouts.removeAtIndex(index)
    inputLayout.parentLayout = nil
    return inputLayout
  }
}

// MARK: - BlockDelegate

extension BlockLayout: BlockDelegate {
  public func blockDidChange(block: Block) {
    // TODO:(vicng) Potentially generate an event to update the corresponding view
  }
}