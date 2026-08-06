package funkin.ui.debug.charting.commands;

#if FEATURE_CHART_EDITOR
import funkin.data.song.SongData.SongEventData;
import funkin.data.song.SongDataUtils;

/**
 * Duplicate the given events, placing the copies at the given offset (in time).
 * Unlike MoveEventsCommand, the original events are left untouched; only the new copies are added.
 *
 * Used by the mobile "long-press and drag" gesture. See DuplicateNotesCommand for details.
 */
@:nullSafety
@:access(funkin.ui.debug.charting.ChartEditorState)
class DuplicateEventsCommand implements ChartEditorCommand
{
  var sourceEvents:Array<SongEventData>;
  var duplicatedEvents:Array<SongEventData>;
  var offset:Float;

  public function new(sourceEvents:Array<SongEventData>, offset:Float, offsetInSteps:Bool = false)
  {
    // Clone the events so later edits to the original selection don't affect this command's history.
    this.sourceEvents = [for (event in sourceEvents) event.clone()];
    if (offsetInSteps) this.offset = Conductor.instance.getStepTimeInMs(offset);
    else
      this.offset = offset;
    this.duplicatedEvents = [];
  }

  /**
   * Perform the action, duplicating the events into the chart.
   *
   * @param state The ChartEditorState to perform the command on.
   */
  public function execute(state:ChartEditorState):Void
  {
    // Clear any leftover ghost/drag-preview offset on the ORIGINAL events before we move the
    // selection over to the new duplicates, or their sprites will visually stick at the drag
    // position. See `clearDragGhostOverrides` for details.
    state.clearDragGhostOverrides();

    duplicatedEvents = [];

    for (event in sourceEvents)
    {
      var resultEvent = event.clone();
      resultEvent.time = (resultEvent.time + offset).clamp(0, Conductor.instance.getStepTimeInMs(state.songLengthInSteps - (1 * state.noteSnapRatio)));

      duplicatedEvents.push(resultEvent);
    }

    // Note: the original events are intentionally left in currentSongChartEventData, unmodified.
    state.currentSongChartEventData = state.currentSongChartEventData.concat(duplicatedEvents);
    state.currentEventSelection = duplicatedEvents;

    state.playSound(Paths.sound('ui/editors/chart-editor/charting-sounds/note-place'));

    state.saveDataDirty = true;
    state.noteDisplayDirty = true;
    state.notePreviewDirty = true;
    state.editButtonsDirty = true;

    state.sortChartData();
  }

  /**
   * Reverse the action, removing the duplicated events.
   *
   * @param state The ChartEditorState to perform the command on.
   */
  public function undo(state:ChartEditorState):Void
  {
    state.currentSongChartEventData = SongDataUtils.subtractEvents(state.currentSongChartEventData, duplicatedEvents);

    state.currentEventSelection = sourceEvents;

    state.playSound(Paths.sound('ui/editors/chart-editor/charting-sounds/undo'));

    state.saveDataDirty = true;
    state.noteDisplayDirty = true;
    state.notePreviewDirty = true;
    state.editButtonsDirty = true;

    state.sortChartData();
  }

  /**
   * Whether the command should display in the undo/redo menu.
   * This should be `false` if no real actions were actually performed.
   *
   * @param state The ChartEditorState to perform the command on.
   * @return Whether the command should be added to the history.
   */
  public function shouldAddToHistory(state:ChartEditorState):Bool
  {
    return (sourceEvents.length > 0);
  }

  /**
   * Convert the action to a string. Used to display the action in the undo/redo history.
   * @return This command, as a readable string.
   */
  public function toString():String
  {
    var len:Int = sourceEvents.length;
    return 'Duplicate $len Events';
  }
}
#end
