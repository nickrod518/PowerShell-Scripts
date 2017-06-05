#requires -Version 5.0

class Card {
    [CardCollection]$CardCollection
    [CardSuit]$CardSuit
    [CardRank]$CardRank
    [string]$CardName
    [string]$CardImage

    # Constructor
    Card() {
        $this.CardSuit = [CardSuit]([Enum]::GetValues([CardSuit]) | Get-Random)
        $this.CardRank = [CardRank]([Enum]::GetValues([CardRank]) | Get-Random)
        $this.CardName = $this.PrintName()
        $this.CardImage = $this.PrintImage()
    }

    # Constructor
    Card([CardSuit]$CardSuit, [CardRank]$CardRank) {
        [CardSuit]$this.CardSuit = $CardSuit
        [CardRank]$this.CardRank = $CardRank
        $this.CardName = $this.PrintName()
        $this.CardImage = $this.PrintImage()
    }
    
    # Constructor
    Card([CardCollection]$CardCollection, [CardSuit]$CardSuit, [CardRank]$CardRank) {
        [CardCollection]$this.CardCollection = $CardCollection
        [CardSuit]$this.CardSuit = $CardSuit
        [CardRank]$this.CardRank = $CardRank
        $this.CardName = $this.PrintName()
        $this.CardImage = $this.PrintImage()
    }
    
    hidden [string] PrintName() {
        return "$($this.CardRank) of $($this.CardSuit)s"
    }

    hidden [string] PrintImage() {
        $Rank = switch ($this.CardRank) {
            Joker { 'j' }
            Ace { 'A' }
            Two { '2' }
            Three { '3' }
            Four { '4' }
            Five { '5' }
            Six { '6' }
            Seven { '7' }
            Eight { '8' }
            Nine { '9' }
            Ten { '10' }
            Jack { 'J' }
            Queen { 'Q' }
            King { 'K' }
        }

        $Suit = switch ($this.CardSuit) {
            Spade { '♠' }
            Club { '♣' }
            Heart { '♥' }
            Diamond { '♦' }
        }

        return "$Rank$Suit"
    }
}

class CardCollection {
    [string]$Name = 'Deck'
    [System.Collections.ArrayList]$Cards = (New-Object System.Collections.ArrayList)

    CardCollection() { }

    CardCollection([string]$Name) {
        [string]$this.Name = $Name
    }

    CardCollection([string]$Name, [bool]$Jokers) {
        [string]$this.Name = $Name
        $this.NewStandardDeck($Jokers)
    }

    CardCollection([bool]$Jokers) {
        $this.NewStandardDeck($Jokers)
    }

    CardCollection([string]$Name, [int]$DeckCount) {
        [string]$this.Name = $Name
        for ($i = 0; $i -lt $DeckCount; $i++) {
            $this.NewStandardDeck($false)
        }
    }

    CardCollection([string]$Name, [int]$DeckCount, [bool]$Jokers) {
        [string]$this.Name = $Name
        for ($i = 0; $i -lt $DeckCount; $i++) {
            $this.NewStandardDeck($Jokers)
        }
    }

    CardCollection([int]$DeckCount, [bool]$Jokers) {
        for ($i = 0; $i -lt $DeckCount; $i++) {
            $this.NewStandardDeck($Jokers)
        }
    }

    NewStandardDeck([bool]$Jokers) {
        foreach ($CardSuit in [enum]::GetValues([CardSuit])) {
            foreach ($CardRank in [enum]::GetValues([CardRank])) {
                if ($Jokers -or [int]$CardRank -gt 0) {
                    $this.Push([Card]::new($this, $CardSuit, $CardRank))
                }
            }
        }

        $this.Shuffle()
    }

    [void] Clear() {
        $this.Cards = New-Object System.Collections.ArrayList
    }

    [void] Push([Card]$Card) {
        Write-Verbose "Adding $($Card.PrintImage()) to $($this.Name)."
        $Card.CardCollection = $this
        $this.Cards.Add($Card)
    }

    [Card] Pop() {
        $Card = $this.Cards[-1]
        Write-Verbose "Removing $($Card.PrintImage()) from $($this.Name)."
        $Card.CardCollection = $null
        $this.Cards.Remove($Card)
        return $Card
    }

    [void] Shuffle() {
        $this.Cards = $this.Cards | Sort-Object { Get-Random }
    }

    [string[]] PrintCards() {
        return ($this.Cards.GetEnumerator() | ForEach-Object { $_.PrintImage() }) -join ', '
    }
}

class Player {
    [CardCollection]$Hand = [CardCollection]::new()
    [bool]$Active
    [int]$Player

    Player([int]$Player) {
        [int]$this.Player = $Player
    }

    [void] DrawHand([CardCollection]$Deck, [int]$HandMax) {
        while ($this.Hand.Cards.Count -lt $HandMax) {
            $this.Hand.Push($Deck.Pop())
        }
    }
}

class Game {
    [int]$ActivePlayer
    [CardCollection]$Deck
    [Player[]]$Players
    [int]$HandSize

    Game([int]$PlayerCount, [int]$HandSize) {
        $this.Deck = [CardCollection]::new($false)

        for ($i = 0; $i -lt $PlayerCount; $i++) {
            $this.Players += [Player]::new($i)
        }
        
        $this.Players.DrawHand($this.Deck, $HandSize)
    }
}

enum CardSuit {
    Spade = 0
    Club = 1
    Heart = 2
    Diamond = 3
}

enum CardRank {
    Joker = 0
    Ace = 1
    Two = 2
    Three = 3
    Four = 4
    Five = 5
    Six = 6
    Seven = 7
    Eight = 8
    Nine = 9
    Ten = 10
    Jack = 11
    Queen = 12
    King = 13
}