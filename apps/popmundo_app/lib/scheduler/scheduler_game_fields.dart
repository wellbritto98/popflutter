import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

/// Discovered character, item and bonus choices. Saved rules can render their
/// effect without these lists until the user asks to change the target.
class SchedulerGameFields extends StatelessWidget {
  const SchedulerGameFields({
    super.key,
    required this.crew,
    required this.pending,
    required this.locked,
    this.loading = false,
    this.catalog,
    this.character,
    this.items = const [],
    this.itemName,
    this.crewOptions,
    this.bonusLevel,
    this.effect,
    this.onCharacter,
    this.onItem,
    this.onBonus,
    this.onChangeTarget,
  });

  final bool crew, pending, locked, loading;
  final GameCharacterCatalog? catalog;
  final GameCharacter? character;
  final List<GameItemChoice> items;
  final String? itemName;
  final GameCrewOptions? crewOptions;
  final int? bonusLevel;
  final String? effect;
  final ValueChanged<GameCharacter>? onCharacter;
  final ValueChanged<String>? onItem;
  final ValueChanged<int>? onBonus;
  final VoidCallback? onChangeTarget;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (loading)
        Padding(
          key: const Key('schedule-options-loading'),
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('scheduler.loadingChoices'.tr())),
            ],
          ),
        ),
      if (crew)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text('scheduler.weeklyBonusLimit'.tr()),
        ),
      if (effect != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(effect!, key: const Key('schedule-effect')),
        ),
      if (locked && character != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(character!.name),
        ),
      if (locked)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('schedule-change-target'),
            onPressed: pending ? null : onChangeTarget,
            child: Text('scheduler.changeTarget'.tr()),
          ),
        )
      else ...[
        if (catalog != null) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final option in catalog!.characters)
                ChoiceChip(
                  key: Key('schedule-character-${option.id}'),
                  label: Text(option.name),
                  selected: character?.id == option.id,
                  onSelected: pending || onCharacter == null
                      ? null
                      : (_) => onCharacter!(option),
                ),
            ],
          ),
        ],
        if (!crew)
          Wrap(
            spacing: 8,
            children: [
              for (final option in items)
                ChoiceChip(
                  key: Key('schedule-item-${option.name}'),
                  label: Text(option.name),
                  selected: itemName == option.name,
                  onSelected: pending || onItem == null
                      ? null
                      : (_) => onItem!(option.name),
                ),
            ],
          ),
        if (crew && crewOptions != null) ...[
          if (crewOptions!.bonuses.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'scheduler.crewUnavailableNow'.tr(),
                key: const Key('schedule-crew-unavailable'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'scheduler.artistLine'.tr(args: [crewOptions!.artistName]),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final bonus in crewOptions!.bonuses)
                ChoiceChip(
                  key: Key('schedule-bonus-${bonus.level}'),
                  label: Text(
                    'scheduler.bonusOption'.tr(
                      args: [bonus.label, bonus.costMinor.toString()],
                    ),
                  ),
                  selected: bonusLevel == bonus.level,
                  onSelected: pending || onBonus == null
                      ? null
                      : (_) => onBonus!(bonus.level),
                ),
            ],
          ),
        ],
      ],
    ],
  );
}
